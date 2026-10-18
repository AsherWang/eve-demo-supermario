from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
from pathlib import Path

from PIL import Image, ImageChops


LOGICAL_SIZE = (256, 240)
FRAME_NUMBER = re.compile(r"(\d+)$")


def frame_map(directory: Path) -> dict[int, Path]:
    result: dict[int, Path] = {}
    for path in sorted(directory.glob("*.png")):
        match = FRAME_NUMBER.search(path.stem)
        if match:
            result[int(match.group(1))] = path
    return result


def normalize(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGB")
    if image.size == LOGICAL_SIZE:
        return image
    width, height = image.size
    if width % LOGICAL_SIZE[0] or height % LOGICAL_SIZE[1]:
        raise ValueError(f"{path} is {image.size}; expected 256x240 or an integer multiple")
    if width // LOGICAL_SIZE[0] != height // LOGICAL_SIZE[1]:
        raise ValueError(f"{path} has non-uniform logical scaling: {image.size}")
    return image.resize(LOGICAL_SIZE, Image.Resampling.NEAREST)


def image_sha256(image: Image.Image) -> str:
    return hashlib.sha256(image.tobytes()).hexdigest()


def compare(reference: Image.Image, actual: Image.Image, tolerance: int) -> dict:
    difference = ImageChops.difference(reference, actual)
    mismatch_count = 0
    absolute_error = 0
    max_error = 0
    for red, green, blue in difference.getdata():
        pixel_max = max(red, green, blue)
        if pixel_max > tolerance:
            mismatch_count += 1
        absolute_error += red + green + blue
        max_error = max(max_error, pixel_max)
    pixel_count = reference.width * reference.height
    return {
        "mismatched_pixels": mismatch_count,
        "mismatch_ratio": mismatch_count / pixel_count,
        "mean_absolute_channel_error": absolute_error / (pixel_count * 3),
        "max_channel_error": max_error,
        "reference_sha256": image_sha256(reference),
        "actual_sha256": image_sha256(actual),
        "difference": difference,
    }


def save_difference(difference: Image.Image, destination: Path, tolerance: int) -> None:
    pixels = []
    for red, green, blue in difference.getdata():
        amount = max(red, green, blue)
        pixels.append((255, max(32, amount), 0) if amount > tolerance else (0, 0, 0))
    visual = Image.new("RGB", difference.size)
    visual.putdata(pixels)
    visual.resize((512, 480), Image.Resampling.NEAREST).save(destination)


def write_html(report: dict, output: Path) -> None:
    rows = []
    for item in report["frames"]:
        if item["status"] == "match":
            continue
        frame = item["frame"]
        links = ""
        if item.get("diff_image"):
            links = f'<a href="{html.escape(item["diff_image"])}">差异图</a>'
        rows.append(
            "<tr>"
            f"<td>{frame}</td><td>{html.escape(item['status'])}</td>"
            f"<td>{item.get('mismatched_pixels', '-')}</td>"
            f"<td>{item.get('max_channel_error', '-')}</td><td>{links}</td>"
            "</tr>"
        )
    document = f"""<!doctype html>
<meta charset="utf-8">
<title>SMB parity report</title>
<style>body{{font-family:system-ui;margin:2rem}}table{{border-collapse:collapse}}td,th{{border:1px solid #aaa;padding:.35rem .6rem}}.pass{{color:#087b26}}.fail{{color:#b00020}}</style>
<h1>SMB 逐帧对照报告</h1>
<p class="{'pass' if report['passed'] else 'fail'}">{'通过' if report['passed'] else '失败'}</p>
<p>比较 {report['compared_frames']} 帧；不一致 {report['failed_frames']} 帧；缺失 {report['missing_frames']} 帧。</p>
<table><thead><tr><th>帧</th><th>状态</th><th>差异像素</th><th>最大通道差</th><th>证据</th></tr></thead><tbody>
{''.join(rows) if rows else '<tr><td colspan="5">全部匹配</td></tr>'}
</tbody></table>
"""
    (output / "report.html").write_text(document, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare normalized 256x240 reference and remake frames.")
    parser.add_argument("--reference", type=Path, required=True, help="Reference frames directory")
    parser.add_argument("--actual", type=Path, required=True, help="EVEngine frames directory")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--channel-tolerance", type=int, default=0)
    parser.add_argument("--max-mismatched-pixels", type=int, default=0)
    parser.add_argument("--max-diff-images", type=int, default=40)
    args = parser.parse_args()

    output = args.output.resolve()
    diff_dir = output / "diff"
    diff_dir.mkdir(parents=True, exist_ok=True)
    reference = frame_map(args.reference.resolve())
    actual = frame_map(args.actual.resolve())
    all_frames = sorted(set(reference) | set(actual))
    results = []
    diff_count = 0
    failed = 0
    missing = 0
    for frame in all_frames:
        if frame not in reference or frame not in actual:
            missing += 1
            failed += 1
            results.append({"frame": frame, "status": "missing-reference" if frame not in reference else "missing-actual"})
            continue
        reference_image = normalize(reference[frame])
        actual_image = normalize(actual[frame])
        metrics = compare(reference_image, actual_image, args.channel_tolerance)
        mismatch = metrics["mismatched_pixels"] > args.max_mismatched_pixels
        item = {key: value for key, value in metrics.items() if key != "difference"}
        item.update({"frame": frame, "status": "mismatch" if mismatch else "match"})
        if mismatch:
            failed += 1
            if diff_count < args.max_diff_images:
                diff_name = f"diff-{frame:06d}.png"
                save_difference(metrics["difference"], diff_dir / diff_name, args.channel_tolerance)
                item["diff_image"] = f"diff/{diff_name}"
                diff_count += 1
        results.append(item)

    report = {
        "schema": "smb-parity-report-v1",
        "passed": bool(all_frames) and failed == 0,
        "logical_size": list(LOGICAL_SIZE),
        "channel_tolerance": args.channel_tolerance,
        "max_mismatched_pixels": args.max_mismatched_pixels,
        "compared_frames": len(all_frames) - missing,
        "failed_frames": failed,
        "missing_frames": missing,
        "frames": results,
    }
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    write_html(report, output)
    print(f"{'PASS' if report['passed'] else 'FAIL'}: {output / 'report.html'}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
