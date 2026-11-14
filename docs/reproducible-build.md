# Reproducing the BeagleY-AI image

This project keeps board-specific Yocto changes in `meta-beagley-edgeai` and
kernel changes in `linux-beagley`. TI's `oe-layersetup` remains the workspace
bootstrap and supplies the Processor SDK 11.02.02 layer set.

## Versioned inputs

| Input | Repository or configuration | Revision |
| --- | --- | --- |
| TI layer set | `configs/processor-sdk-analytics/processor-sdk-analytics-11.02.02-config.txt` in TI `oe-layersetup` | TI-pinned commits in that file |
| BeagleY-AI layer | `meta-beagley-edgeai` | Pin the reviewed project commit here when publishing a build |
| BeagleY-AI kernel | `linux-beagley`, branch `beagley/6.12` | `380dd018bcd73f7b23b75f937495c85739f8dc71` |
| Machine | `beagley-ai` | `build/conf/local.conf` |
| Image | `tisdk-edgeai-image` | BitBake image recipe |

The layer and kernel repositories must be available from a shared Git server
before another machine can reproduce this build. Once published, replace the
layer revision above with its full commit SHA and record the repository URLs in
the project release notes. Do not use a moving branch name or `AUTOREV` as the
release identifier.

## Set up a workspace

Clone TI's `oe-layersetup` repository, then initialize its Processor SDK
Analytics 11.02.02 sources using the configuration listed above. Clone the
published `meta-beagley-edgeai` and `linux-beagley` repositories into the
workspace's `sources/` directory, checking out the published SHAs. Add the
BeagleY-AI layer to `build/conf/bblayers.conf` and set:

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
