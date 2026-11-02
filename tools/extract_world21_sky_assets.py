"""Extract the ROM cloud-platform sprite used by World 2-1's sky bonus."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
from extract_world21 import EXPECTED
from extract_smb_assets import find_once, tile_image, decode_tile
ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom",type=Path,default=ROOT/"roms/Super Mario Bros. (World).nes")
    args=parser.parse_args();raw=args.rom.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=EXPECTED: parser.error("unverified ROM")
    prg=raw[16:32784];chr_data=raw[32784:40976]
    at=find_once(prg,bytes.fromhex("3f00200f291a0f0f36170f0f30210f0f27170f"),"ground palette")
    palette=list(prg[at+27:at+31])
    image=Image.new("RGBA",(48,8))
    for x in range(0,48,8):image.alpha_composite(tile_image(chr_data,0x75,palette,0,True),(x,0))
    target=ROOT/"assets/world21/cloud-platform.png";image.save(target)
    # Sprite zero wins sprite priority even with its behind-background bit.
    # Restore the already-rendered HUD background only at its opaque CHR pixels.
    sprite_zero=decode_tile(chr_data,0xff,0)
    masks=[]
    for phase in range(6):
        coin=Image.open(ROOT/f"assets/items/hud-coin-{phase}.png").convert("RGBA")
        mask=Image.new("RGBA",(8,8))
        for y in range(8):
            for x in range(8):
                if not sprite_zero[y*8+x]:continue
                color=coin.getpixel((x,y+1)) if y<7 else (0,0,0,0)
                if color[3]==0:color=(146,144,255,255)
                mask.putpixel((x,y),color)
        dest=ROOT/f"assets/world21/hud-sprite0-{phase}.png";mask.save(dest)
        masks.append(dict(path=dest.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(dest.read_bytes()).hexdigest()))
    (ROOT/"assets/world21/sky-assets-manifest.json").write_text(json.dumps(dict(
        rom_sha256=EXPECTED,tile=0x75,sprite_palette=2,width=48,height=8,
        output_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),sprite_zero_masks=masks),indent=2)+"\n")
if __name__=="__main__":main()
