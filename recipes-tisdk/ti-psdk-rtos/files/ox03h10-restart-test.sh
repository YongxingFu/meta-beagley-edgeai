#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ox03h10-restart-test [options]

Run repeated OX03H10 -> VISS -> H.264/RTP starts and verify that the PC
actually receives a decodable image after every start.

Options:
  -p BOARD      SSH target for board (default: root@10.42.0.247)
  -r PORT       UDP/RTP port (default: 5030)
  -c COUNT      Number of start/stop cycles (default: 10)
  -f FRAMES     Frames per stream process (default: 120)
  -e RECEIVER   PC receiver script
  -o DIR        Output directory (default: /tmp/ox03h10-restart-test)
  -h            Show this help

Environment overrides:
  WIDTH/HEIGHT  Expected decoded image size (default: 1920x1536)
  START_WAIT    Seconds to wait before starting each sender (default: 1)
  STOP_WAIT     Seconds to wait after each sender exits (default: 1)
  SEND_TIMEOUT  Maximum seconds for one sender run (default: 25)
EOF
}

BOARD="${BOARD:-root@10.42.0.247}"
PORT="${PORT:-5030}"
COUNT="${COUNT:-10}"
FRAMES="${FRAMES:-120}"
RECEIVER="${RECEIVER:-}"
OUT_DIR="${OUT_DIR:-/tmp/ox03h10-restart-test}"
WIDTH="${WIDTH:-1920}"
HEIGHT="${HEIGHT:-1536}"
START_WAIT="${START_WAIT:-1}"
STOP_WAIT="${STOP_WAIT:-1}"
SEND_TIMEOUT="${SEND_TIMEOUT:-25}"

while getopts ":p:r:c:f:e:o:h" opt; do
    case "$opt" in
        p) BOARD="$OPTARG" ;;
        r) PORT="$OPTARG" ;;
        c) COUNT="$OPTARG" ;;
        f) FRAMES="$OPTARG" ;;
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

for value in PORT COUNT FRAMES WIDTH HEIGHT SEND_TIMEOUT; do
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

PC_IP="$(ip -4 route get "${BOARD#*@}" |
    awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')"
if [[ -z "$PC_IP" ]]; then
    echo "Unable to determine PC IP for board ${BOARD#*@}" >&2
    exit 2
fi

mkdir -p "$OUT_DIR"
active_receiver=""

cleanup() {
    if [[ -n "$active_receiver" ]] && kill -0 "$active_receiver" 2>/dev/null; then
        kill -TERM "$active_receiver" 2>/dev/null || true
        wait "$active_receiver" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

validate_jpeg() {
    local image="$1"

    python3 - "$image" "$WIDTH" "$HEIGHT" <<'PY'
import sys
from PIL import Image, ImageStat

path = sys.argv[1]
expected_size = (int(sys.argv[2]), int(sys.argv[3]))

with Image.open(path) as image:
    image.load()
    if image.size != expected_size:
        raise SystemExit(
            f"unexpected image size {image.size}, expected {expected_size}"
        )
    rgb = image.convert("RGB")
    stat = ImageStat.Stat(rgb)
    means = tuple(round(v, 3) for v in stat.mean)
    stddev = tuple(round(v, 3) for v in stat.stddev)
    extrema = rgb.getextrema()

if max(stat.stddev) < 0.1 or all(low == high for low, high in extrema):
    raise SystemExit(f"uniform image: mean={means}, stddev={stddev}")

print(f"jpeg_mean={means} jpeg_stddev={stddev}")
PY
}

echo "OX03H10 restart test: ${COUNT} cycles, ${FRAMES} frames/cycle"
echo "board=$BOARD pc_ip=$PC_IP port=$PORT receiver=$RECEIVER"
echo "results=$OUT_DIR"

pass=0
fail=0
declare -a results=()

for ((cycle = 1; cycle <= COUNT; cycle++)); do
    sender_log="$OUT_DIR/send-${cycle}.log"
    receiver_log="$OUT_DIR/receive-${cycle}.log"
    image="$OUT_DIR/restart-${cycle}.jpg"
    rm -f "$sender_log" "$receiver_log" "$image"

    timeout $((SEND_TIMEOUT + 10))s \
        "$RECEIVER" -m snapshot -p "$PORT" -o "$image" \
        >"$receiver_log" 2>&1 &
    active_receiver=$!
    sleep "$START_WAIT"

    start_ns="$(date +%s%N)"
    set +e
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$BOARD" \
        "timeout -s INT ${SEND_TIMEOUT}s ox03h10-stream \
          -p '$PC_IP' -r '$PORT' -f '$FRAMES'" \
        >"$sender_log" 2>&1
    send_rc=$?
    set -e
    elapsed_ms=$(( ($(date +%s%N) - start_ns) / 1000000 ))

    set +e
    wait "$active_receiver"
    recv_rc=$?
    set -e
    active_receiver=""

    valid=no
    detail=""
    if [[ -s "$image" ]]; then
        set +e
        detail="$(validate_jpeg "$image" 2>&1)"
        validate_rc=$?
        set -e
        if (( validate_rc == 0 )); then
            valid=yes
        fi
    else
        detail="receiver produced no JPEG"
    fi

    if (( send_rc == 0 )) && [[ "$valid" == "yes" ]]; then
        result=PASS
        ((pass += 1))
    else
        result=FAIL
        ((fail += 1))
    fi
    results+=("$cycle $result send_rc=$send_rc recv_rc=$recv_rc elapsed_ms=$elapsed_ms $detail")
    printf 'START %d %s send_rc=%d recv_rc=%d elapsed_ms=%d %s\n' \
        "$cycle" "$result" "$send_rc" "$recv_rc" "$elapsed_ms" "$detail"

    if (( send_rc == 124 || send_rc == 130 )); then
        echo "Sender did not exit normally; stopping before the VISS state is reused." >&2
        break
    fi
    if grep -q -E \
        'TIVX_CMD_NODE_CREATE failed|com\.ti\.hwa\.vpac_viss.*failed' \
        "$sender_log" 2>/dev/null; then
        echo "VISS node creation failed; stopping before subsequent retries." >&2
        break
    fi

    sleep "$STOP_WAIT"
done

printf '%s\n' "${results[@]}" >"$OUT_DIR/results.txt"
echo "PASS=$pass/$COUNT"
if (( pass != COUNT )); then
    exit 1
fi
