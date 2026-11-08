#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$project_dir/build"
. conf/setenv
export MACHINE=beagley-ai LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
mkdir -p logs
exec 9> .beagley-edgeai-build.lock
flock -n 9 || { echo "A BeagleY-AI image build is already running" >&2; exit 1; }
printf '%s\n' "$$" > logs/beagley-edgeai-build.pid
if [[ "${1:-}" == "--wait-pid" ]]; then
    while kill -0 "$2" 2>/dev/null; do sleep 2; done
fi
printf '\nBuild started: %s\n' "$(date -Iseconds)" >> logs/beagley-edgeai-build.log
echo "Building BeagleY-AI Edge AI image; log: $BUILDDIR/logs/beagley-edgeai-build.log"
exec systemd-inhibit --what=sleep --who=Codex --why="BeagleY-AI Yocto image build" \
    --mode=block bitbake -k tisdk-edgeai-image >> logs/beagley-edgeai-build.log 2>&1
