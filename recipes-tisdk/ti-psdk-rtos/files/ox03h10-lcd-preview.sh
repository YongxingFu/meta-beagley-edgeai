#!/usr/bin/env bash
# OX03H10 -> VISS -> BeagleY-AI OLDI LCD. Ctrl-C stops preview.
set -euo pipefail

MEDIA_DEVICE=${MEDIA_DEVICE:-/dev/media0}
VIDEO_DEVICE=${VIDEO_DEVICE:-/dev/video3}
DRM_DEVICE=${DRM_DEVICE:-30200000.dss}
CONNECTOR_ID=${CONNECTOR_ID:-41}
PLANE_ID=${PLANE_ID:-42}
DCC_VISS_FILE=${DCC_VISS_FILE:-/opt/imaging/ox03h10/wdr/dcc_viss_wdr_304.bin}
DCC_2A_FILE=${DCC_2A_FILE:-/opt/imaging/ox03h10/wdr/dcc_2a_wdr_304.bin}
BACKLIGHT_DEVICE=${BACKLIGHT_DEVICE:-/sys/class/backlight/backlight-yx50093act}

# The cold-boot default may be zero when the systemd backlight restorer is masked.
if [[ -d "$BACKLIGHT_DEVICE" ]]; then
    cat "$BACKLIGHT_DEVICE/max_brightness" > "$BACKLIGHT_DEVICE/brightness"
fi

for path in "$MEDIA_DEVICE" "$VIDEO_DEVICE" "$DCC_VISS_FILE" "$DCC_2A_FILE"; do
    [[ -e "$path" ]] || { echo "Missing required device or file: $path" >&2; exit 1; }
done
for entity in 'max96717 6-0040' 'max96716a 5-0028' 'cdns_csi2rx.30101000.csi-bridge' '30102000.ticsi2rx'; do
    media-ctl -d "$MEDIA_DEVICE" --set-v4l2 "\"$entity\":0[fmt:SBGGR12_1X12/1920x1536 field:none]"
done

# Keep the native 5:4 aspect ratio: tidss scales to 600x480 on 800x480.
# 2A is disabled to match the validated OX03H10 fixed-exposure baseline.
exec gst-launch-1.0 -e \
    v4l2src device="$VIDEO_DEVICE" io-mode=dmabuf ! \
    'video/x-bayer,format=bggr12,width=1920,height=1536,framerate=60/1' ! \
    tiovxisp sensor-name=SENSOR_OX03H10 format-msb=11 num-exposures=1 \
        wdr-enabled=true bypass-dwb=true dcc-isp-file="$DCC_VISS_FILE" \
        sink_0::dcc-2a-file="$DCC_2A_FILE" sink_0::ae-mode=2 sink_0::awb-mode=2 ! \
    'video/x-raw,format=NV12,width=1920,height=1536,framerate=60/1' ! \
    queue leaky=downstream max-size-buffers=2 ! \
    fpsdisplaysink text-overlay=false sync=false \
        video-sink="kmssink driver-name=tidss bus-id=$DRM_DEVICE connector-id=$CONNECTOR_ID plane-id=$PLANE_ID sync=false"
