#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ox03h10-receive [options]

Receive and display the OX03H10 H.264/RTP stream from the board.

Options:
  -p PORT       UDP/RTP port (default: 5000)
  -l LATENCY    rtpjitterbuffer latency in ms (default: 100)
  -m MODE       display, stats, or snapshot (default: display)
  -o FILE       JPEG output for snapshot mode (default: /tmp/ox03h10-frame.jpg)
  -s SINK       Video sink for display mode (default: autovideosink)
  -h            Show this help
EOF
}

PORT="${PORT:-5000}"
LATENCY="${LATENCY:-100}"
MODE="${MODE:-display}"
SNAPSHOT_FILE="${SNAPSHOT_FILE:-/tmp/ox03h10-frame.jpg}"
VIDEO_SINK="${VIDEO_SINK:-autovideosink}"

while getopts ":p:l:m:o:s:h" opt; do
    case "$opt" in
        p) PORT="$OPTARG" ;;
        l) LATENCY="$OPTARG" ;;
        m) MODE="$OPTARG" ;;
        o) SNAPSHOT_FILE="$OPTARG" ;;
        s) VIDEO_SINK="$OPTARG" ;;
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

CAPS="application/x-rtp,media=video,encoding-name=H264,payload=96,clock-rate=90000"
RTP_INPUT=(
    udpsrc address=0.0.0.0 port="$PORT" caps="$CAPS" !
    rtpjitterbuffer latency="$LATENCY" drop-on-latency=true !
    rtph264depay !
    h264parse !
    avdec_h264 !
    videoconvert
)

case "$MODE" in
    display)
        exec gst-launch-1.0 -v "${RTP_INPUT[@]}" ! \
            fpsdisplaysink video-sink="$VIDEO_SINK" text-overlay=true sync=false
        ;;
    stats)
        exec gst-launch-1.0 -v "${RTP_INPUT[@]}" ! \
            fpsdisplaysink video-sink=fakesink text-overlay=false sync=false
        ;;
    snapshot)
        exec gst-launch-1.0 -e -v "${RTP_INPUT[@]}" ! \
            jpegenc snapshot=true quality=90 ! \
            filesink location="$SNAPSHOT_FILE"
        ;;
    *)
        echo "-m must be display, stats, or snapshot" >&2
        exit 2
        ;;
esac
