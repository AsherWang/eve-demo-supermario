from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


NES_BUTTON_BITS = {
    "a": 0x01,
    "b": 0x02,
    "select": 0x04,
    "start": 0x08,
    "up": 0x10,
    "down": 0x20,
    "left": 0x40,
    "right": 0x80,
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_movie(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != "smb-parity-movie-v1":
        raise ValueError("movie schema must be smb-parity-movie-v1")
    frames = data.get("frames")
    if not isinstance(frames, int) or frames <= 0:
        raise ValueError("movie.frames must be a positive integer")
    for section_name in ("inputs",):
        _validate_inputs(data.get(section_name, []), frames, section_name)
    bootstrap = data.get("reference_bootstrap", {})
    bootstrap_frames = bootstrap.get("frames", 0)
    if not isinstance(bootstrap_frames, int) or bootstrap_frames < 0:
        raise ValueError("reference_bootstrap.frames must be a non-negative integer")
    _validate_inputs(bootstrap.get("inputs", []), bootstrap_frames, "reference_bootstrap.inputs")
    captures = data.get("capture_frames", list(range(frames)))
    if not isinstance(captures, list) or any(not isinstance(value, int) for value in captures):
        raise ValueError("capture_frames must be an integer array")
    if any(value < 0 or value >= frames for value in captures):
        raise ValueError("capture_frames contains a frame outside the comparison timeline")
    if not captures or frames - 1 not in captures:
        raise ValueError("capture_frames must include the final comparison frame")
    return data


def _validate_inputs(inputs: Any, frame_count: int, label: str) -> None:
    if not isinstance(inputs, list):
        raise ValueError(f"{label} must be an array")
    for index, item in enumerate(inputs):
        if not isinstance(item, dict):
            raise ValueError(f"{label}[{index}] must be an object")
        start = item.get("start")
        end = item.get("end")
        port = item.get("port", 0)
        buttons = item.get("buttons")
        if not isinstance(start, int) or not isinstance(end, int) or start < 0 or end < start:
            raise ValueError(f"{label}[{index}] has an invalid inclusive frame range")
        if end >= frame_count:
            raise ValueError(f"{label}[{index}] exceeds its section frame count")
        if port not in (0, 1):
            raise ValueError(f"{label}[{index}].port must be 0 or 1")
        if not isinstance(buttons, list) or not buttons:
            raise ValueError(f"{label}[{index}].buttons must be a non-empty array")
        unknown = [button for button in buttons if button not in NES_BUTTON_BITS]
        if unknown:
            raise ValueError(f"{label}[{index}] has unknown buttons: {unknown}")


def expand_input_masks(movie: dict[str, Any]) -> list[int]:
    masks = [0] * movie["frames"]
    for item in movie.get("inputs", []):
        if item.get("port", 0) != 0:
            continue
        mask = 0
        for button in item["buttons"]:
            mask |= NES_BUTTON_BITS[button]
        for frame in range(item["start"], item["end"] + 1):
            masks[frame] |= mask
    return masks


def mesen_input_arguments(movie: dict[str, Any]) -> list[str]:
    args: list[str] = []
    bootstrap = movie.get("reference_bootstrap", {})
    offset = bootstrap.get("frames", 0)
    for item in bootstrap.get("inputs", []):
        buttons = ",".join(item["buttons"])
        args.extend(["--input", f"{item.get('port', 0)}:{buttons}@{item['start']}-{item['end']}"])
    for item in movie.get("inputs", []):
        buttons = ",".join(item["buttons"])
        args.extend([
            "--input",
            f"{item.get('port', 0)}:{buttons}@{item['start'] + offset}-{item['end'] + offset}",
        ])
    return args


def mesen_section_input_arguments(inputs: list[dict[str, Any]], offset: int = 0) -> list[str]:
    args: list[str] = []
    for item in inputs:
        buttons = ",".join(item["buttons"])
        args.extend([
            "--input",
            f"{item.get('port', 0)}:{buttons}@{item['start'] + offset}-{item['end'] + offset}",
        ])
    return args
