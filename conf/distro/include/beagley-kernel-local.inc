# Opt-in local Git source, enabled from build/conf/local.conf.
# Fetches a committed revision; uncommitted checkout changes are not built.
BEAGLEY_KERNEL_LOCAL_PATH ?= "${TOPDIR}/../sources/linux-beagley"
BEAGLEY_KERNEL_BRANCH ?= "beagley/6.12-snapshot"
BEAGLEY_KERNEL_SRCREV ?= "2fe5bb7cad42dd9269f9347d0806c797a210796c"

KERNEL_GIT_URI:beagley-ai = "git://${BEAGLEY_KERNEL_LOCAL_PATH}"
KERNEL_GIT_PROTOCOL:beagley-ai = "file"
BRANCH:pn-linux-bb.org:beagley-ai = "${BEAGLEY_KERNEL_BRANCH}"
SRCREV:pn-linux-bb.org:beagley-ai = "${BEAGLEY_KERNEL_SRCREV}"
