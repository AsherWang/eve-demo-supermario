"""Extract the original title overlay from the verified ROM's CHR VRAM packet."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
from extract_smb_assets import find_once, tile_image

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = 'f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom', type=Path, default=ROOT/'roms/Super Mario Bros. (World).nes')
    args = parser.parse_args()
    raw = args.rom.read_bytes()
    if hashlib.sha256(raw).hexdigest() != EXPECTED:
        parser.error('unverified ROM')
    prg, chr_data = raw[16:32784], raw[32784:]
    packet = chr_data[0x1ec0:0x1ec0+0x13a]
    writes = {}
    cursor = 0
    while packet[cursor]:
        address = packet[cursor]*256+packet[cursor+1]
        control = packet[cursor+2]
        cursor += 3
        count, stride = control & 63, 32 if control & 128 else 1
        if not count:
            raise ValueError('empty title packet command')
        for i in range(count):
            writes[address+i*stride] = packet[cursor if control & 64 else cursor+i]
        cursor += 1 if control & 64 else count
    palette_at = find_once(prg, bytes.fromhex('3f00200f291a0f0f36170f0f30210f0f27170f'), 'ground palette')
    palette = prg[palette_at+3:palette_at+19]
    overlay = Image.new('RGBA', (256, 240))
    for address, tile in writes.items():
        if not 0x2000 <= address < 0x23c0:
            continue
        offset = address-0x2000
        x, y = offset % 32, offset // 32
        attr = writes.get(0x23c0+(y//4)*8+x//4, 0)
        group = (attr >> (((y//2) % 2)*4+((x//2) % 2)*2)) & 3
        overlay.alpha_composite(tile_image(chr_data, tile, list(palette[group*4:group*4+4]), 1, True), (x*8, y*8))
    # Mushroom menu cursor is the ROM's 1-player selection packet at $2249.
    overlay.alpha_composite(tile_image(chr_data, 0xce, list(palette[4:8]), 1, True), (72, 144))
    overlay.paste((0, 0, 0, 0), (136, 184, 184, 192))
    out = ROOT/'assets/title'
    out.mkdir(exist_ok=True)
    overlay.save(out/'overlay.png')
    (ROOT/'scripts/generated/title_data.nut').write_text(
        '// Original CHR title packet copied to RAM $0300 by CopyTitleScreen.\n'
        'ROM_TITLE_PACKET <- ['+','.join(map(str,packet))+'];\n', encoding='utf-8')
    (out/'manifest.json').write_text(json.dumps(dict(
        schema='smb-title-overlay-v1', rom_sha256=EXPECTED,
        source='CHR $1ec0 VRAM packet, background pattern table 1',
        packet_sha256=hashlib.sha256(packet).hexdigest(),
        packet_bytes=cursor+1, writes=len(writes)), indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main()
