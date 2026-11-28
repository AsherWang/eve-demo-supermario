"""Offline World 3-1 fixture; game runtime never reads or writes emulator RAM."""
def build_world31_origin_lua(checkpoint_page: int=0) -> str:
    if not 0<=checkpoint_page<=12: raise ValueError('checkpoint outside World 3-1')
    return f'''
local selected=false
local found=false
local frame=0
emu.addEventCallback(function()
  local ram=emu.memType.nesInternalRam
  if not selected and emu.read(0x0770,ram)==1 and emu.read(0x000e,ram)==8 then
    selected=true
    emu.write(0x075f,2,ram) -- WorldNumber: world 2
    emu.write(0x075c,0,ram) -- LevelNumber: stage 1
    emu.write(0x0760,0,ram) -- AreaNumber: first area
    emu.write(0x0750,0x24,ram) -- World3Areas[0]
    emu.write(0x0752,0,ram)
    emu.write(0x075b,{checkpoint_page},ram)
    emu.write(0x0757,1,ram)
    emu.write(0x0769,1,ram)
    emu.write(0x0772,0,ram)
  elseif selected and not found and emu.read(0x075f,ram)==2
     and emu.read(0x075c,ram)==0
     -- The destination pointer can already select a bonus link at checkpoints.
     -- Match the active L_GroundArea5 object-data base instead.
     and emu.read(0x00e7,ram)==0x1b and emu.read(0x00e8,ram)==0xa6
     and emu.read(0x0770,ram)==1 and emu.read(0x0772,ram)==3
     and emu.read(0x000e,ram)==8 and emu.read(0x0774,ram)==0 then
    found=true
    emu.log("PARITY_ORIGIN frame="..frame.." world=3 level=1")
  end
  frame=frame+1
end,emu.eventType.endFrame)
'''
