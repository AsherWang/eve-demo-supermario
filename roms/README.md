# Local ROM

`Super Mario Bros. (World).nes` is the user-supplied ROM used by this personal
study project. Its SHA-256 is:

```text
f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de
```

The file matches `assets/audio/oracle-audio-manifest.json` and the local parity
test data. It is intentionally kept in the source tree for this local workflow;
it is not bundled into the packaged game or linked into EVEngine. Do not publish
or redistribute the ROM without permission from its rights holder.

The release packager copies only runtime files,
`assets`, `scripts` and `native`; it never copies `roms/` or any `.nes` file.

From the project root, the parity suite can use it directly:

```powershell
python tools\parity\run_suite.py --rom "roms\Super Mario Bros. (World).nes"
```
