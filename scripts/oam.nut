// PPU sprite evaluation for the runtime's native 8x8 OAM cells. Transparent
// cells still occupy one of the eight sprite slots on each visible scanline.
// Other actor renderers retain their existing paths; this is not a PPU core.
oamCollecting <- false;
oamMasking <- false;
oamBase <- 0;
oamEntries <- {};
oamLineMasks <- {};
if (!("oamTexturePaths" in getroottable())) oamTexturePaths <- {};
if (!("oamMaskedTextures" in getroottable())) oamMaskedTextures <- {};

function world21OamOffset(g,slot) {
    local phase="displayOamPhase" in g.world21?g.world21.displayOamPhase:0;
    local amounts=[0,0x58,0xa0];
    local offset=0x30+slot*24+amounts[phase];
    return offset>=256?(offset+0x28)&255:offset;
}

function evaluateOamScanlines(entries) {
    local keys=[],counts=array(240,0),masks={};
    foreach(key,entry in entries) keys.append(key);
    keys.sort();
    foreach(key in keys) {
        local mask=0;
        for(local row=0;row<8;row+=1) {
            local y=entries[key].y+row;
            // The viewport already clips these pixels. Retain their texels
            // rather than creating an unnecessary partially empty GPU texture.
            if(y<0 || y>=240) {mask=mask | (1<<row);continue;}
            if(counts[y]<8) mask=mask | (1<<row);
            counts[y]+=1;
        }
        masks[key] <- mask;
    }
    return masks;
}

function maskedOamCell(texture,mask) {
    if(mask==255) return texture;
    if(mask==0) return null;
    if(!(texture in oamMaskedTextures)) oamMaskedTextures[texture] <- {};
    local variants=oamMaskedTextures[texture];
    if(mask in variants) return variants[mask];
    // The public SDK has no texture-region draw call. Create and cache only
    // the rare clipped 8x8 variants, preserving the checked-in source pixels.
    local pixels=eve.Image().newImageDataFromFile(oamTexturePaths[texture]);
    for(local row=0;row<8;row+=1) if((mask & (1<<row))==0)
        for(local x=0;x<8;x+=1) pixels.setPixel(x,row,0.0,0.0,0.0,0.0);
    local clipped=gfx.newTexture(pixels,false,false);
    gfx.setTextureSampler(clipped,"nearest","none",1.0,0.0);
    variants[mask] <- clipped;
    return clipped;
}

function runOamScanlineSelfTest() {
    local entries={};
    for(local i=0;i<9;i+=1) entries[i*4] <- {y=10};
    local masks=evaluateOamScanlines(entries);
    requireSelfTest(masks[28]==255 && masks[32]==0,
        "the ninth OAM cell must be hidden even if preceding tiles are transparent");
    entries[32].y=14;masks=evaluateOamScanlines(entries);
    requireSelfTest(masks[32]==0xf0,
        "sprite overflow must mask individual scanlines, not the entire 8x8 cell");
    entries={};entries[0x80] <- {y=238};entries[0x04] <- {y=238};
    masks=evaluateOamScanlines(entries);
    requireSelfTest(masks[4]==255 && masks[0x80]==255,
        "viewport clipping must not be mistaken for sprite overflow");
}
