"""World 2-4 normal entrance selector, used only before comparison frame zero."""
from run_reference import build_origin_lua

def build_world24_origin_lua(checkpoint_page=0):
    if checkpoint_page != 0:
        raise ValueError('World 2-4 has no midpoint')
    source=build_origin_lua(4)
    source=source.replace('selected = true', 'selected = true\n    emu.write(0x075f, 1, emu.memType.nesInternalRam)')
    source=source.replace('emu.write(0x0750, 96,', 'emu.write(0x0750, 98,')
    return source.replace('World 1-4','World 2-4')
