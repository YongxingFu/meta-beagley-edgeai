# OX03H10 fixed topology GMSL camera

The active kernel source is `sources/linux-beagley`, branch `beagley/6.12`,
revision `0437cebcb1316ba9b7046fc147ce7daa24cced0d`. Yocto pins this revision in
`conf/distro/include/beagley-kernel-local.inc`.

```text
OX03H10 (0x36) -> MAX96717 (0x40) -> MAX96716A (0x28) -> AM67A CSI0
```

The mode is 1920x1536 BGGR RAW12 at 60 fps. The three drivers and register
profiles are maintained in the kernel repository. The layer enables
`CONFIG_VIDEO_OX03H10`, `CONFIG_VIDEO_MAX96717` and `CONFIG_VIDEO_MAX96716A`,
installs their modules, builds the CSI0 camera overlay and enables it in
`uEnv.txt`. The memory-map overlay remains enabled alongside the camera.

The MAX96717 baseline starts the sensor before serializer CSI output,
propagates stream formats, rolls back failed starts and retains the 500 ms
initialization delay. No CSI restart, TPG validation bypass or experimental
MAX96716A lock-wait patch is applied by this layer.

On 2026-11-10, the original baseline commit `14dbaed8e5e2` was built and tested:
RAW 3 x 300 frames at 59.67 fps and 600 frames at 59.84 fps;
VISS 3 x 300 frames and 1800 frames at 58.50 fps; HDMI 300 frames with no drops
at about 8.54 fps. The tested MAX96717 module SHA256 was
`f7636f8dfecf8c59f273ab80397002e72f725b0d0449b57136995e2af43acf8c`.
The revision above cherry-picks the same change onto the main kernel branch,
which also contains the OLED changes; that combined image still needs a build
and board acceptance test. Automatic AE/AWB and colour calibration remain open.

For media setup see `scripts/ox03h10-camera-configure.sh` in yocto-build.
It assumes the tested node numbering; verify `media-ctl -p` before use.
ISP, RTP and validation details are in `docs/ox03h10-isp-streaming.md` there.
