#!/usr/bin/env bash
set -eu
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
root="$project_dir/downloads/git2"
mkdir -p "$root"
prime() {
 local path="$1" rev="$2" branch="$3" dest="$root/git.ti.com.git.${1//\//.}.git" tmp
 if [[ -d "$dest" ]] && git --git-dir="$dest" cat-file -e "$rev^{commit}" 2>/dev/null; then echo "cached $path"; return; fi
 tmp=$(mktemp -d "$root/.prime-XXXXXX")
 git init -q --bare "$tmp/repo"
 if git --git-dir="$tmp/repo" fetch -q --depth=1 "https://git.ti.com/git/$path.git" "$rev" && git --git-dir="$tmp/repo" update-ref "refs/heads/$branch" "$rev"; then
  git --git-dir="$tmp/repo" config remote.origin.url "https://git.ti.com/git/$path.git"
  if [[ ! -e "$dest" ]]; then mv "$tmp/repo" "$dest"; echo "OK $path"; else echo "EXISTS BUT MISSING REVISION $dest"; rm -rf "$tmp"; return 1; fi
 else echo "FAILED $path"; rm -rf "$tmp"; return 1; fi
 rm -rf "$tmp"
}
prime edgeai/edgeai-apps-utils 3a80d12341b4df80500572c0f01d969113ad0655 main
prime edgeai/edgeai-tiovx-kernels b336fcf451eb0a6c44b23273e091e74e29daa393 main
prime edgeai/edgeai-dl-inferer d06b07d3058b1859df0e32c3ca545b70b8cf3ec9 main
prime edgeai/edgeai-tiovx-modules bbfa4f370c266e6cee53926d1dd301ab01660452 main
prime apps/edgeai-gui-app b2220eaa3f335bc77b928a57e2325dd1881c5bc0 master
prime processor-sdk-vision/arm-tidl 7c813ac3e2d5e271f414661abbf8586a89f6bda1 11.2.x_sdk
prime processor-sdk/concerto f5541b85b9973ca47680d1a6d970bf61a126daa8 main
