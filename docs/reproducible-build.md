# Reproducing the BeagleY-AI image

This project keeps board-specific Yocto changes in `meta-beagley-edgeai` and
kernel changes in `linux-beagley`. TI's `oe-layersetup` remains the workspace
bootstrap and supplies the Processor SDK 11.02.02 layer set.

## Versioned inputs

| Input | Repository or configuration | Revision |
| --- | --- | --- |
| TI layer set | `configs/processor-sdk-analytics/processor-sdk-analytics-11.02.02-config.txt` in TI `oe-layersetup` | TI-pinned commits in that file |
| BeagleY-AI layer | `meta-beagley-edgeai` | Pin the reviewed project commit here when publishing a build |
| BeagleY-AI kernel | `https://github.com/YongxingFu/linux-beagley.git`, branch `beagley/6.12-snapshot` | `2fe5bb7cad42dd9269f9347d0806c797a210796c` (single-commit source snapshot) |
| Machine | `beagley-ai` | `build/conf/local.conf` |
| Image | `tisdk-edgeai-image` | BitBake image recipe |

The kernel snapshot is published on GitHub. The layer repository URL is
`https://github.com/YongxingFu/meta-beagley-edgeai.git`; use its reviewed commit
SHA when checking out a release. The kernel snapshot intentionally omits the
upstream commit history to reduce the initial transfer. Do not use a moving
branch name or `AUTOREV` as the release identifier.

## Set up a workspace

Clone TI's `oe-layersetup` repository, then initialize its Processor SDK
Analytics 11.02.02 sources using the configuration listed above. Clone the
published project layer and compact kernel snapshot into `sources/`:

```bash
git clone https://github.com/YongxingFu/meta-beagley-edgeai.git sources/meta-beagley-edgeai
git -C sources/meta-beagley-edgeai checkout <reviewed-layer-commit>
git clone --depth=1 --branch beagley/6.12-snapshot https://github.com/YongxingFu/linux-beagley.git sources/linux-beagley
git -C sources/linux-beagley checkout --detach 2fe5bb7cad42dd9269f9347d0806c797a210796c
```

Add the BeagleY-AI layer to `build/conf/bblayers.conf` and set:

```bitbake
MACHINE = "beagley-ai"
require conf/distro/include/beagley-kernel-local.inc
```

The kernel include expects the project checkout at
`${TOPDIR}/../sources/linux-beagley`; override `BEAGLEY_KERNEL_LOCAL_PATH` if
the workspace layout differs. It fetches the recorded committed kernel SHA
from that local Git checkout, so uncommitted kernel edits are not part of the
image.

## Build

```bash
cd build
. conf/setenv
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
MACHINE=beagley-ai bitbake tisdk-edgeai-image
```

The WIC image is written under the build's deploy directory in
`images/beagley-ai/`. Record the exact layer commit, kernel commit, TI
configuration, and image SHA-256 for each released image.

## Workspace versus project source

Keep `build/`, `downloads/`, BitBake work directories, logs, and generated WIC
images in local build or artifact storage. They are outputs and caches, not
project source. Keep TI's `oe-layersetup` checkout on its upstream history;
project-specific recipes, patches, scripts, and documentation belong in
`meta-beagley-edgeai`, and kernel code belongs in `linux-beagley`.
