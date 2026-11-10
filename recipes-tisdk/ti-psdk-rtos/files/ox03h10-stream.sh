#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ox03h10-stream [options]

Stream OX03H10 through TI VISS/H.264 to an RTP receiver.

Options:
  -p PC_IP      Receiver IPv4 address (default: board default gateway)
  -r PORT       UDP/RTP port (default: 5000)
  -b BITRATE    H.264 bitrate in bit/s (default: 12000000)
  -f FRAMES     Stop after FRAMES frames; 0 streams until interrupted
  -m MODE       disabled or auto for AE/AWB (default: disabled)
  -h            Show this help

Environment overrides:
  VIDEO_DEVICE  Default /dev/video3
  DCC_VISS_FILE Default /opt/imaging/ox03h10/wdr/dcc_viss_wdr_304.bin
  DCC_2A_FILE   Default /opt/imaging/ox03h10/wdr/dcc_2a_wdr_304.bin
  FPS           Default 60
  WIDTH/HEIGHT  Default 1920/1536
  KEYFRAME      Default FPS
EOF
}

PC_IP=""
PORT="${PORT:-5000}"
BITRATE="${BITRATE:-12000000}"
FRAMES="${FRAMES:-0}"
AE_AWB_MODE="${AE_AWB_MODE:-disabled}"

while getopts ":p:r:b:f:m:h" opt; do
    case "$opt" in
        p) PC_IP="$OPTARG" ;;
        r) PORT="$OPTARG" ;;
        b) BITRATE="$OPTARG" ;;
        f) FRAMES="$OPTARG" ;;
        m) AE_AWB_MODE="$OPTARG" ;;
        h)
            usage
            exit 0
            ;;
        :)
            echo "Missing argument for -$OPTARG" >&2
            usage >&2
            exit 2
            ;;
        \?)
            echo "Unknown option: -$OPTARG" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ -z "$PC_IP" ]]; then
    PC_IP="$(ip route show default | awk 'NR == 1 { print $3 }')"
fi
if [[ -z "$PC_IP" ]]; then
    echo "Unable to determine PC_IP; pass -p PC_IP" >&2
    exit 2
fi

VIDEO_DEVICE="${VIDEO_DEVICE:-/dev/video3}"
DCC_VISS_FILE="${DCC_VISS_FILE:-/opt/imaging/ox03h10/wdr/dcc_viss_wdr_304.bin}"
DCC_2A_FILE="${DCC_2A_FILE:-/opt/imaging/ox03h10/wdr/dcc_2a_wdr_304.bin}"
FPS="${FPS:-60}"
WIDTH="${WIDTH:-1920}"
HEIGHT="${HEIGHT:-1536}"
KEYFRAME="${KEYFRAME:-$FPS}"

for required in "$VIDEO_DEVICE" "$DCC_VISS_FILE" "$DCC_2A_FILE"; do
    if [[ ! -e "$required" ]]; then
        echo "Required path does not exist: $required" >&2
        exit 1
    fi
done

case "$AE_AWB_MODE" in
    disabled)
        TWOA_PROPERTIES="sink_0::ae-mode=2 sink_0::awb-mode=2"
        ;;
    auto)
        TWOA_PROPERTIES=""
        ;;
    *)
        echo "-m must be disabled or auto" >&2
        exit 2
        ;;
esac

NUM_BUFFERS_PROPERTY=""
if (( FRAMES > 0 )); then
    NUM_BUFFERS_PROPERTY="num-buffers=$FRAMES"
fi

echo "OX03H10 -> VISS -> H.264/RTP/${PORT} -> ${PC_IP}" >&2
exec gst-launch-1.0 -e -q \
    v4l2src device="$VIDEO_DEVICE" io-mode=dmabuf $NUM_BUFFERS_PROPERTY ! \
    "video/x-bayer,format=bggr12,width=${WIDTH},height=${HEIGHT},framerate=${FPS}/1" ! \
    tiovxisp sensor-name=SENSOR_OX03H10 format-msb=11 num-exposures=1 \
        wdr-enabled=true \
        dcc-isp-file="$DCC_VISS_FILE" \
        sink_0::dcc-2a-file="$DCC_2A_FILE" \
        $TWOA_PROPERTIES ! \
    "video/x-raw,format=NV12,width=${WIDTH},height=${HEIGHT},framerate=${FPS}/1" ! \
    v4l2h264enc extra-controls="controls,video_bitrate=${BITRATE},h264_i_frame_period=${KEYFRAME}" ! \
    h264parse config-interval=1 ! \
    rtph264pay config-interval=1 pt=96 ! \
    udpsink host="$PC_IP" port="$PORT" sync=false async=false
