#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ox03h10-endurance-test [options]

Run a finite-frame OX03H10 -> VISS -> H.264/RTP endurance test and collect
board, network, decoder and PC frame statistics.

Options:
  -p BOARD      SSH target for board (default: root@10.42.0.247)
  -r PORT       UDP/RTP port (default: 5040)
  -d SECONDS    Test duration (default: 600)
  -f FPS        Stream frame rate and stream duration basis (default: 60)
  -b BITRATE    H.264 bitrate in bit/s (default: 12000000)
  -e RECEIVER   PC receiver script
  -o DIR        Output directory (default: /tmp/ox03h10-endurance)
  -h            Show this help

Environment overrides:
  START_WAIT    Seconds between receiver and sender start (default: 2)
  STOP_WAIT     Seconds after sender EOS before receiver teardown (default: 3)
EOF
}

BOARD="${BOARD:-root@10.42.0.247}"
PORT="${PORT:-5040}"
DURATION="${DURATION:-600}"
FPS="${FPS:-60}"
BITRATE="${BITRATE:-12000000}"
RECEIVER="${RECEIVER:-}"
OUT_DIR="${OUT_DIR:-/tmp/ox03h10-endurance}"
START_WAIT="${START_WAIT:-2}"
STOP_WAIT="${STOP_WAIT:-3}"

while getopts ":p:r:d:f:b:e:o:h" opt; do
    case "$opt" in
        p) BOARD="$OPTARG" ;;
        r) PORT="$OPTARG" ;;
        d) DURATION="$OPTARG" ;;
        f) FPS="$OPTARG" ;;
        b) BITRATE="$OPTARG" ;;
        e) RECEIVER="$OPTARG" ;;
        o) OUT_DIR="$OPTARG" ;;
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

for value in PORT DURATION FPS BITRATE; do
    if [[ ! "${!value}" =~ ^[0-9]+$ ]] || (( ${!value} == 0 )); then
        echo "$value must be a positive integer, got: ${!value}" >&2
        exit 2
    fi
done
if (( PORT > 65535 )); then
    echo "PORT must be <= 65535" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$RECEIVER" ]]; then
    for candidate in \
        "$SCRIPT_DIR/ox03h10-receive" \
        "$SCRIPT_DIR/ox03h10-receive.sh" \
        "/usr/share/ox03h10/ox03h10-receive"; do
        if [[ -x "$candidate" ]]; then
            RECEIVER="$candidate"
            break
        fi
    done
fi
if [[ -z "$RECEIVER" || ! -x "$RECEIVER" ]]; then
    echo "Unable to find an executable receiver; pass -e RECEIVER" >&2
    exit 2
fi

BOARD_HOST="${BOARD#*@}"
PC_IP="$(ip -4 route get "$BOARD_HOST" |
    awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')"
PC_IF="$(ip -4 route get "$BOARD_HOST" |
    awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')"
if [[ -z "$PC_IP" || -z "$PC_IF" ]]; then
    echo "Unable to determine PC IP/interface for board $BOARD_HOST" >&2
    exit 2
fi

BOARD_IF="$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$BOARD" \
    "ip -4 route get '$PC_IP' | awk '{ for (i = 1; i <= NF; i++) if (\$i == \"dev\") { print \$(i + 1); exit } }'")"
if [[ -z "$BOARD_IF" ]]; then
    echo "Unable to determine board interface for PC $PC_IP" >&2
    exit 2
fi

read_pc_rx() {
    cat "/sys/class/net/$PC_IF/statistics/rx_bytes"
}

read_board_tx() {
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$BOARD" \
        "cat '/sys/class/net/$BOARD_IF/statistics/tx_bytes'"
}

mkdir -p "$OUT_DIR"
sender_log="$OUT_DIR/sender.log"
receiver_log="$OUT_DIR/receiver.log"
summary="$OUT_DIR/summary.txt"
frames=$((DURATION * FPS))
active_receiver=""
active_sender=""

cleanup() {
    if [[ -n "$active_sender" ]] && kill -0 "$active_sender" 2>/dev/null; then
        kill -TERM "$active_sender" 2>/dev/null || true
        wait "$active_sender" 2>/dev/null || true
    fi
    if [[ -n "$active_receiver" ]] && kill -0 "$active_receiver" 2>/dev/null; then
        kill -TERM "$active_receiver" 2>/dev/null || true
        wait "$active_receiver" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

rm -f "$sender_log" "$receiver_log" "$summary"

echo "OX03H10 endurance test: ${DURATION}s, ${frames} frames at ${FPS} fps"
echo "board=$BOARD board_if=$BOARD_IF pc_ip=$PC_IP pc_if=$PC_IF port=$PORT"
echo "results=$OUT_DIR"

timeout -k 5s $((DURATION + 60))s \
    "$RECEIVER" -m stats -p "$PORT" >"$receiver_log" 2>&1 &
active_receiver=$!
sleep "$START_WAIT"

pc_rx_start="$(read_pc_rx)"
board_tx_start="$(read_board_tx)"
wall_start_ns="$(date +%s%N)"

ssh -o BatchMode=yes -o ConnectTimeout=5 "$BOARD" \
    "timeout -k 10s -s INT $((DURATION + 60))s ox03h10-stream \
      -p '$PC_IP' -r '$PORT' -f '$frames' -b '$BITRATE'" \
    >"$sender_log" 2>&1 &
active_sender=$!

sample=""
sleep_seconds=$((DURATION < 30 ? DURATION : 30))
sleep "$sleep_seconds"
if kill -0 "$active_sender" 2>/dev/null; then
    sample="$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$BOARD" \
        "ps -eo pcpu=,rss=,comm= | awk '/gst-launch/ { print \$1, \$2; exit }'")" || true
fi

set +e
wait "$active_sender"
sender_rc=$?
set -e
active_sender=""
sleep "$STOP_WAIT"

board_tx_end="$(read_board_tx)"
pc_rx_end="$(read_pc_rx)"
wall_end_ns="$(date +%s%N)"

if kill -0 "$active_receiver" 2>/dev/null; then
    kill -TERM "$active_receiver" 2>/dev/null || true
fi
set +e
wait "$active_receiver"
receiver_rc=$?
set -e
active_receiver=""

elapsed_s="$(awk -v start="$wall_start_ns" -v end="$wall_end_ns" \
    'BEGIN { printf "%.3f", (end - start) / 1000000000 }')"
board_tx_bytes=$((board_tx_end - board_tx_start))
pc_rx_bytes=$((pc_rx_end - pc_rx_start))
board_mbps="$(awk -v bytes="$board_tx_bytes" -v seconds="$elapsed_s" \
    'BEGIN { printf "%.3f", bytes * 8 / seconds / 1000000 }')"
pc_mbps="$(awk -v bytes="$pc_rx_bytes" -v seconds="$elapsed_s" \
    'BEGIN { printf "%.3f", bytes * 8 / seconds / 1000000 }')"

read -r current_fps average_fps dropped rendered < <(
    python3 - "$receiver_log" <<'PY'
import re
import sys

last = None
pattern = re.compile(
    r"rendered:\s*(\d+),\s*dropped:\s*(\d+),\s*"
    r"current:\s*([0-9.]+),\s*average:\s*([0-9.]+)"
)
with open(sys.argv[1], encoding="utf-8", errors="replace") as log:
    for line in log:
        match = pattern.search(line)
        if match:
            last = match

if last is None:
    print("0 0 0 0")
else:
    rendered, dropped, current, average = last.groups()
    print(current, average, dropped, rendered)
PY
)

board_error_count="$(grep -E -c \
    'ERROR: from element|Invalid Desc Id|AWB_TI_process returned error|TI_2A_wrapper_process returned error|too many regions|TIVX_CMD_NODE_CREATE failed|com\.ti\.hwa\.vpac_viss.*failed' \
    "$sender_log" || true)"
receiver_error_count="$(grep -E -c 'ERROR:|Internal data stream error' \
    "$receiver_log" || true)"

status=FAIL
if (( sender_rc == 0 )) &&
   awk -v fps="$average_fps" 'BEGIN { exit !(fps >= 30) }' &&
   (( dropped == 0 )) &&
   (( board_error_count == 0 )) &&
   (( receiver_error_count == 0 )) &&
   (( rendered > 0 )); then
    status=PASS
fi

cat >"$summary" <<EOF
status=$status
sender_rc=$sender_rc
receiver_rc=$receiver_rc
elapsed_s=$elapsed_s
requested_frames=$frames
board_network_tx_bytes=$board_tx_bytes
board_network_mbps=$board_mbps
pc_network_rx_bytes=$pc_rx_bytes
pc_network_mbps=$pc_mbps
pc_rendered=$rendered
pc_dropped=$dropped
pc_current_fps=$current_fps
pc_average_fps=$average_fps
board_cpu_rss_sample=$sample
board_error_count=$board_error_count
receiver_error_count=$receiver_error_count
sender_log=$sender_log
receiver_log=$receiver_log
EOF

cat "$summary"
[[ "$status" == "PASS" ]]
