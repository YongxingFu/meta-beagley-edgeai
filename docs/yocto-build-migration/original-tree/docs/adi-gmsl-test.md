# BeagleY-AI ADI GMSL test (2026-11-09)

- Kernel source: `sources/linux-beagley-adi-test`, branch `test/adi-gmsl`, committed baseline `a6cc0768640ad448c79da59b013372905a9c2b0d`.
- Build: `source sources/oe-core/oe-init-build-env build-adi && bitbake linux-bb.org`. The kernel release is `6.12.57-adi-ti`; build and deploy matching kernel, modules, DTB and overlays together.
- Board: `10.42.0.247` at test time. Independent files are `/boot/Image-6.12.57-adi-ti`, `/usr/lib/modules/6.12.57-adi-ti`, and `/boot/dtb/ti/*-adi*`.
- U-Boot config is `/run/media/boot-mmcblk1p1/uEnv.txt`; `uEnv.pre-adi.txt` is the original and `uEnv.adi.txt` is the first ADI setup. To switch, copy the desired saved file to `uEnv.txt`, sync, and reboot. If the board cannot boot, mount the SD card boot partition on another machine and restore `uEnv.pre-adi.txt` as `uEnv.txt`.
- MAX96716A and MAX96717 bound to ADI drivers. The OX03H10 initially fails identification; driving MAX96717 MFP0 high and retrying the I2C probe exposed ID `58:03:48`. A GPIO hog alone still needed a later retry. The uncommitted source changes add the hog and a 500 ms clock settling delay; they are unbuilt and not validated.
- All pads were set to `SBGGR12_1X12/1920x1536 field:none colorspace:raw`; capture timed out with a zero-byte file. During streaming serializer `pclkdet` was 1 and deserializer `video_lock` was 0. Counter values alone do not identify the fault.
- The deserializer internal RGB888 test pattern at 640x480 also timed out on each separately tested output port (DT ports 2 and 3). This suggests investigating output PHY/CSI configuration and test-pattern setup; it does not prove a wiring fault.
- The port-3 overlay `/boot/dtb/ti/k3-am67a-beagley-ai-ox03h10-adi-port3.dtbo` was produced as an experiment; it is not part of the committed build.

## MAX96716A internal TPG: successful capture

The independent board overlay `/boot/dtb/ti/k3-am67a-beagley-ai-ox03h10-adi-400.dtbo` changes only the deserializer CSI output endpoint link frequency from 750 MHz to 400 MHz (800 Mbit/s per lane). The original ADI and legacy boot configs remain saved. This is a test overlay, not a validated production configuration. A decompiled version is saved as `docs/beagley-adi-tpg-400-overlay.dts`.

Using the ADI driver, route MAX96716A TPG pad 4 to source pad 2, configure RGB888 640x480 field none on the deserializer TPG and receiver pads, and configure `/dev/video3` as XR24. A ten-frame capture produced 12,288,000 bytes and a two-colour checkerboard; the first frame is `docs/beagley-adi-tpg.png`. A subsequent 600-frame capture completed at about 60.01 fps, with zero occurrences of `CRC error` in dmesg before and after the test. This tests the deserializer's internal pixel-mode pattern and CSI output path only. It does not validate the 6 Gbit/s GMSL tunnel or sensor capture. At 750 MHz equivalent tests timed out, but the exact cause of the difference has not been established.

After a reboot the sensor may not bind immediately; the full media topology may require releasing MAX96717 MFP0 and retrying sensor probe, as described above. The board currently boots using the 400 MHz test overlay. To restore the initial ADI configuration, copy `uEnv.adi.txt` to `uEnv.txt`; to restore the original kernel, copy `uEnv.pre-adi.txt` to `uEnv.txt` and reboot. On a warm switch from ADI to legacy, the serializer may remain at alias `0x41`; the legacy driver expects `0x40`, requiring a reset/power cycle or explicit restoration of the serializer address before reprobe.

Example after the media graph has bound the sensor (entity names and video node must be checked with `media-ctl -p`):

```sh
media-ctl -R '"max9296a 4-0028" [4/0 -> 2/0 [1]]'
media-ctl -V '"max9296a 4-0028":4 [fmt:RGB888_1X24/640x480 field:none colorspace:srgb]'
media-ctl -V '"cdns_csi2rx.30101000.csi-bridge":0 [fmt:RGB888_1X24/640x480 field:none colorspace:srgb]'
media-ctl -V '"30102000.ticsi2rx":0 [fmt:RGB888_1X24/640x480 field:none colorspace:srgb]'
v4l2-ctl -d /dev/video3 --set-fmt-video=width=640,height=480,pixelformat=XR24
timeout 30 v4l2-ctl -d /dev/video3 --stream-mmap=4 --stream-count=600 --stream-to=/dev/null
```

## OX03H10 camera test through 6 Gbit/s GMSL tunnel

At 400 MHz CSI link-frequency, the ADI camera route captured 10 BG12 frames (58,982,400 bytes). A grayscale contrast-stretched preview and the first unmodified 16-bit-container BG12 frame are saved under `backups/adi-camera-test/`. The preview is not demosaiced or colour-corrected. MAX96717 and MAX96716A reported tunnel mode and 6 Gbit/s while the short capture was running.

A follow-up capture requested 300 frames with a 60 second timeout. It timed out after 229 frame markers. Its reported rate initially reached about 50–56 fps but later dropped to single digits; the dmesg count matching `CRC error` was zero before and after. This is not a comprehensive hardware error-counter measurement and does not establish zero physical-layer errors.

A temporary 600 MHz CSI link-frequency overlay also produced 10 frames, but its 300-frame capture timed out after 199 frame markers in about 61 seconds. The reported rate briefly reached 60 fps and later fell with intermittent bursts; dmesg again contained zero `CRC error` messages. The 600 and 400 MHz runs were sequential, not controlled repetitions, so neither demonstrates a root cause. Both operated with sensor mode advertised as 1920x1536 RAW12 at 60 fps. The earlier observation that the source CSV labels VTS=814 remains unresolved.

## User-performed cold power cycle: 400 MHz

After the user reported a full power cycle on 2026-11-09, the board booted `6.12.57-adi-ti` with the 400 MHz overlay. Sensor initial probe failed with `-121`; after manually holding MAX96717 MFP0 high the first retry read ID `00:03:48`, and the second read the expected `58:03:48`. The 10-frame RAW12 capture succeeded (58,982,400 bytes); the first frame and grayscale preview are `backups/adi-camera-test/ox03h10-cold-400mhz-first.raw` and `ox03h10-cold-400mhz-preview.png`.

The same 300-frame / 60-second test timed out with 79 v4l2-ctl frame markers; reported rates were generally about 1–3 fps with bursts. The kernel log contained zero lines matching `CRC error` before and after, which does not establish that all SerDes/CSI hardware counters are clear. The 400 MHz warm run previously recorded 229 frames in 60 seconds. These are single runs, and v4l2-ctl includes startup time; the result demonstrates non-repeatable performance but does not isolate cause. RAW preview shows apparent geometric distortion, subject to sensor geometry, capture packing, and preview interpretation not yet independently verified.

## MAX96717 internal test pattern after cold cycle

On the same cold-started 400 MHz CSI setup, the MAX96717 internal TPG was routed through MAX96716A to the SoC. During capture both ADI subdevices reported pixel mode, and the deserializer reported GMSL2 6 Gbit/s. This test does not exercise tunnel mode or the OX03H10 input.

- RGB888 640x480@60: 600/600 frames, about 60.03 fps, with no dmesg lines matching `CRC error` before or after. The captured checkerboard had visible discontinuities and speckles. Compared to the first of ten frames, 16.58–57.99% of RGB pixels differed in each later frame. Earlier MAX96716A internal TPG frames captured in the same nominal format had no pixel differences among ten frames. This does not by itself establish whether the 96717 TPG output, pixel-mode SerDes routing, GMSL, or capture is responsible.
- RGB888 1920x1080@30: 300/300 frames at about 30.02 fps, no dmesg lines matching `CRC error`. Three additional frames were captured; 36.49% and 44.72% of RGB pixels differed from the first. No claim of valid image content is based solely on successful frame completion.
- Preview images: `backups/adi-camera-test/max96717-tpg-preview.png` and `max96717-tpg-1080-preview.png`; first run log `max96717-tpg-600.log`.

The camera route and RAW12 format were restored after the test. The result raises the priority of investigating the 96717 TPG and the pixel-mode path before attributing camera stalling solely to the sensor. The TPG's frame pattern stability and its mode transitions should be verified against device documentation and register observations.

## Legacy architecture MAX96717 internal TPG comparison

After a user-reported complete power cycle, the legacy `6.12.57-ti` kernel and MAX96716A/MAX96717 drivers bound; the sensor ID was `58:03:48`. The pre-existing serializer test-pattern control could not stream RGB because the media pipeline validated the physical RAW12 sensor link and the serializer forwarded the sensor frame descriptor. A temporary legacy test module in `sources/linux-beagley-legacy-tpg` adds a test-pattern-only exception for link validation and an RGB888 frame descriptor; it also includes the existing Yocto serializer patches. It was built as an external module against the existing kernel build. Scripts and built module are under `backups/legacy717-tpg/`.

The first attempt to hot reload caused media entity registration warnings. After restoring through a full board/SerDes power cycle and loading the test module on boot, the media topology was clean. A temporary userspace register setup disabled MAX96716A tunnel mode and changed its pixel data-type remaps to RGB888; cleanup restored `0x0474=0x09`, the RAW12 remap, and serializer test_pattern=0.

At RGB888 640x480, the old 75 MHz TPG timing generated approximately 155.28 fps, not 60 fps: 600/600 frames completed. The first of ten saved frames had a black region; compared with frame 2, frames 3–9 matched exactly and frame 10 differed by 0.0033% of RGB pixels. Preview of frame 2: `backups/adi-camera-test/legacy717-tpg-frame2.png`. At 1920x1080 the test completed 300/300 frames at approximately 30.2 fps; on a separate four-frame sample, frames 3 and 4 differed from frame 2 at 0.0111% and 0.0068% of RGB pixels respectively. Preview: `backups/adi-camera-test/legacy717-tpg-1080-preview.png`. There were no kernel log lines matching `CRC error` during these short tests, which does not rule out hardware errors or demonstrate long-term stability.

The same MAX96717 physical device, 6 Gbit/s board link, and legacy pixel-mode path produced largely consistent frames after startup, compared with changing frames in the ADI-framework pixel-mode test. The 640x480 frame rates differ (155 vs 60 fps), and legacy source timing and deserializer settings also differ. Crucially, the legacy deserializer uses a fixed register profile for its PHY; the temporary overlay reports 400 MHz to Linux but does not reprogram that fixed profile. Therefore this is not a controlled same-CSI-rate A/B comparison. Further source/register and timing comparison is needed before assigning a cause.

The original installed serializer module was backed up at `/root/max96717-original-6.12.57-ti.ko.xz` and restored on disk after testing. The temporary test module remains loaded in memory until the next reboot; test pattern is disabled, deserializer tunnel register is restored, and the media graph was returned to camera RAW12 format. The board remains on the independent legacy-400 test overlay; original and ADI boot configs are saved as described above.

## Legacy vs ADI 717 TPG register comparison

On the legacy test module, 1920x1080 RGB888 TPG ran at about 30 fps and runtime register blocks were captured in `backups/legacy717-tpg/legacy-1080-registers.log`. The board was then warm-rebooted into the ADI 400 MHz overlay; the sensor was manually released/reprobed, and ADI TPG at 1920x1080@30 was recorded in `adi-1080-registers.log`. As this was a warm transition it is not a cold-controlled comparison.

Differences included MAX96717 `0x024e` (legacy 0xfb; ADI 0xf3, including HS inversion) and vertical generator timing (legacy 5-line VS pulse, ADI 16-line VS pulse), and MAX96716A DPLL/PHY and SSC configuration. Under ADI, temporarily changing only `0x024e` to 0xfb while streaming, skipping the first 120 frames, then capturing four frames gave 44.23%, 52.70%, 39.78% RGB-pixel differences from the first frame. Temporarily applying the legacy 0x0250–0x026a timing block and 0xfb gave 47.76%, 55.62%, 54.42% differences. Registers were restored after each test. These are small samples, but neither change reproduced the stable legacy frames. The unmodified ADI pattern was not checked in the exact same skip-120 procedure, so avoid treating the percentages as a controlled quantitative improvement estimate.

## MAX96716A deskew experiment

At the 600 MHz ADI test setup, the legacy and ADI deserializer images differed at the CSI output PHY deskew registers. MAX96716A logical PHY 0 uses hardware PHY 1, so the relevant registers are `0x0443` and `0x0444`. The legacy profile had both at `0x01`; the ADI driver wrote both to `0x00` because its DPLL frequency was below 1.5 GHz. The addresses `0x0403` and `0x0404` belong to unused hardware PHY 0 and do not affect this route.

One manual capture with `0x0443=0x01` and `0x0444=0x01`, using the skip-120 procedure, reduced frame-to-frame RGB differences to 0.0285–0.0319% and produced a uniform checkerboard. A rebuilt ADI driver that programmed the same values during probe did not reproduce the result: after reboot the skipped frames again differed by 46.15%, 48.54%, and 53.81%, despite reading both registers back as `0x01`. A later manual `0x00`-to-`0x01` transition also remained unstable at 49.48%, 54.10%, and 51.03%. The single stable manual sample therefore does not yet establish a complete fix; DPLL initialization ordering, PHY state, or another link setting remains unresolved.

The experimental driver change was reverted in the source tree. The 300-frame driver test still completed at about 30.01–30.74 fps with no `CRC error` lines. The board was then switched from the ADI 600 MHz profile to `/run/media/boot-mmcblk1p1/uEnv.legacy-tpg.txt`; the prior ADI profile was saved as `uEnv.adi-600.txt`. A warm reboot into legacy left MAX96717 at an inaccessible link state (`-EREMOTEIO` reading register `0x000d`), so the serializer did not bind. As observed previously, a complete cold power cycle is required before continuing the real-sensor test on the legacy architecture.

## Legacy architecture real OX03H10 output

After the required cold power cycle, the legacy `6.12.57-ti` kernel bound MAX96717, MAX96716A, and OX03H10. The sensor reported ID `58:03:48`. Restoring tunnel register `0x0474=0x09`, the RAW12 remaps, and `SBGGR12_1X12/1920x1536` formats produced a successful 10-frame, 58,982,400-byte capture.

The first frames contain startup artifacts, but later frames are valid image data. A 30-frame capture showed stable frame statistics after startup; frame 30 is a recognizable grayscale scene. The first unmodified 16-bit-container frame from the earlier 10-frame run and representative previews are:

- `backups/adi-camera-test/legacy-camera-cold-400mhz-first.raw`
- `backups/adi-camera-test/legacy-camera-frame30-preview.png`
- `backups/adi-camera-test/legacy-camera-frames26-30.png`

A 100-frame mmap-only capture reached about 59.03 fps, demonstrating that the sensor path can deliver full-rate frames. Sustained repeat tests were inconsistent: 300-frame captures timed out after 70, 79, 41, and 49 frames in different runs, generally settling near 1–2.5 fps. During those runs MAX96717 `pclkdet` stayed 1, the GMSL link stayed locked, tunnel mode and CSI output remained enabled, and dmesg contained no `CRC error` lines. The cause of the sustained slowdown is therefore not yet isolated between sensor auto-exposure behavior, CSI output headroom, and repeated stream state.

Raising MAX96716A CSI TX DPLL register `0x0320` from `0x2c` to `0x2f` improved one capture that copied frames to userspace from roughly 1.2 to about 18.5 fps, and one mmap-only run reached 60.03 fps. Programming `0x2f` during driver probe, start-output, or after sensor stream start did not reproduce stable performance after reboot. Moving start-output after sensor streaming also did not fix it. All experimental MAX96716A code changes were reverted, and the original module was restored from `/root/max96716a-original-6.12.57-ti.ko.xz`.

A separate `--stream-mmap=32` test requested about 188 MB of DMA buffers against a 144 MiB CMA reservation. This produced `__cma_alloc` and `vb2_dc_alloc` warnings, followed by only three frames. This allocation failure is a test-harness limitation and should not be confused with the earlier sustained-frame-rate behavior. Use at most four to eight buffers for this 5.9 MB RAW frame size.

## Final legacy stability fix

The instability was traced to stream-start ordering rather than the sensor stopping. The legacy serializer enabled its CSI output before starting the upstream OX03H10. The validated reference sequence starts the sensor first and enables the serializer video output afterward.

The legacy drivers now:

- start the sensor before `MAX96717` CSI output and stop it first;
- roll back the upstream stream if serializer output startup fails;
- poll `MAX96716A` GMSL link lock during probe;
- poll `MAX96716A` video-lock status after stream-on and tear down the pipeline on timeout.

The original 400 MHz overlay and `0x0320=0x2c` setting were retained. Tests with 750 MHz overlay and 1400/1500 Mbps/lane produced no host frames even though the sensor frame counter continued near 60 fps, so that bandwidth change is not valid for the current sensor mode without a corresponding sensor PLL/timing change.

Final results:

- 600 frames: 600/600, steady `60.02 fps`.
- Three independent `yavta` captures: `60.056`, `59.992`, and `60.028 fps`.
- Twenty consecutive start/stop cycles: 20/20 passed, 300 frames each.
- OX03H10 frame counter advanced at approximately 60.8-62 fps during streaming.
- DES link/video lock remained asserted; `0x5013` overflow/loss flag stayed clear.
- Preview: `backups/adi-camera-test/final-lock-fix-frame10.png`.

The source changes are in `drivers/media/i2c/max96717.c` and `drivers/media/i2c/max96716a.c` under `sources/linux-beagley-legacy-tpg`. Kernel `checkpatch.pl` reports zero errors and warnings. Scripts for the counter diagnostic, acceptance runs, and repeated start/stop are under `backups/legacy717-tpg/`.
