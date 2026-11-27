"""Offline World 2-2 fixture; game runtime never reads or writes emulator RAM."""
def build_world22_origin_lua(checkpoint_page: int=0) -> str:
    if not 0<=checkpoint_page<=12: raise ValueError('checkpoint outside World 2-2')
    return f'''
local selected=false
local found=false
local frame=0
emu.addEventCallback(function()
  local ram=emu.memType.nesInternalRam
  if not selected and emu.read(0x0770,ram)==1 and emu.read(0x000e,ram)==8 then
    selected=true
    emu.write(0x075f,1,ram) -- WorldNumber: world 2
    emu.write(0x075c,1,ram) -- LevelNumber: stage 2
    emu.write(0x0760,2,ram) -- AreaNumber: water area
    emu.write(0x0750,0x01,ram) -- World2Areas[2]
    emu.write(0x0752,0,ram)
    emu.write(0x075b,{checkpoint_page},ram)
    emu.write(0x0757,1,ram)
    emu.write(0x0769,1,ram)
    emu.write(0x0772,0,ram)
  elseif selected and not found and emu.read(0x075f,ram)==1
     and emu.read(0x075c,ram)==1
     -- The destination pointer can already select a bonus link at checkpoints.
     -- Match the active L_WaterArea2 object-data base instead.
     and emu.read(0x00e7,ram)==0x47 and emu.read(0x00e8,ram)==0xae
     and emu.read(0x0770,ram)==1 and emu.read(0x0772,ram)==3
     and emu.read(0x000e,ram)==8 and emu.read(0x0774,ram)==0 then
    found=true
    emu.log("PARITY_ORIGIN frame="..frame.." world=2 level=2")
  end
  frame=frame+1
end,emu.eventType.endFrame)
'''


def build_world22_entrance_origin_lua() -> str:
    """Select only the area before initialization; never edit in-route state.

    Engine task 7 is the automatic surface entrance, unlike task 8 used by
    water-only probes. All later loading and movement are performed by the ROM.
    """
    return '''
local selected=false
local found=false
local frame=0
emu.addEventCallback(function()
  local ram=emu.memType.nesInternalRam
  if not selected and emu.read(0x0770,ram)==1 and emu.read(0x000e,ram)==8 then
    selected=true
    emu.write(0x075f,1,ram)
    emu.write(0x075c,1,ram)
    emu.write(0x0760,1,ram) -- World2Areas[1]: normal surface introduction
    emu.write(0x0750,0x29,ram)
    emu.write(0x0752,0,ram)
    emu.write(0x075b,0,ram)
    emu.write(0x0757,1,ram)
    emu.write(0x0769,1,ram)
    emu.write(0x0772,0,ram)
  elseif selected and not found and emu.read(0x075f,ram)==1
     and emu.read(0x075c,ram)==1 and emu.read(0x0760,ram)==1
     and emu.read(0x0770,ram)==1 and emu.read(0x0772,ram)==3
     and emu.read(0x000e,ram)==7 and emu.read(0x0774,ram)==0 then
    found=true
    emu.log("PARITY_ORIGIN frame="..frame.." world=2 level=2 origin=normal-entrance")
  end
  frame=frame+1
end,emu.eventType.endFrame)
'''
