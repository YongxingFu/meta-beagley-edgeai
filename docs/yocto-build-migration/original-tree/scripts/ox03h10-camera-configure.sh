#!/bin/sh
set -eu

# Diagnostic setup for the validated legacy topology on BeagleY-AI.
# Verify node numbering with media-ctl -p before use. Stop capture first.

v4l2-ctl -d /dev/v4l-subdev3 --set-ctrl=test_pattern=0
i2ctransfer -f -y 4 w3@0x28 0x04 0x74 0x09
i2ctransfer -f -y 4 w3@0x28 0x04 0x4d 0xac
i2ctransfer -f -y 4 w3@0x28 0x04 0x4e 0x2c
i2ctransfer -f -y 4 w3@0x28 0x04 0x4f 0x80
i2ctransfer -f -y 4 w3@0x28 0x04 0x51 0x81

media-ctl -V '"max96717 5-0040":0 [fmt:SBGGR12_1X12/1920x1536 field:none colorspace:raw]'
media-ctl -V '"max96717 5-0040":1 [fmt:SBGGR12_1X12/1920x1536 field:none colorspace:raw]'
media-ctl -V '"max96716a 4-0028":0 [fmt:SBGGR12_1X12/1920x1536 field:none colorspace:raw]'
media-ctl -V '"max96716a 4-0028":1 [fmt:SBGGR12_1X12/1920x1536 field:none colorspace:raw]'
media-ctl -V '"cdns_csi2rx.30101000.csi-bridge":0 [fmt:SBGGR12_1X12/1920x1536 field:none colorspace:raw]'
media-ctl -V '"30102000.ticsi2rx":0 [fmt:SBGGR12_1X12/1920x1536 field:none colorspace:raw]'
v4l2-ctl -d /dev/video3 --set-fmt-video=width=1920,height=1536,pixelformat=BG12
