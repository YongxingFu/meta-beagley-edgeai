# Opt-in local Git source, enabled from build/conf/local.conf.
# Fetches a committed revision; uncommitted checkout changes are not built.
BEAGLEY_KERNEL_LOCAL_PATH ?= "${TOPDIR}/../sources/linux-beagley"
BEAGLEY_KERNEL_BRANCH ?= "beagley/6.12"
BEAGLEY_KERNEL_SRCREV ?= "1198505462d2df7021771a3e14d6102ab5e16c49"

KERNEL_GIT_URI:beagley-ai = "git://${BEAGLEY_KERNEL_LOCAL_PATH}"
KERNEL_GIT_PROTOCOL:beagley-ai = "file"
BRANCH:beagley-ai = "${BEAGLEY_KERNEL_BRANCH}"
SRCREV:pn-linux-bb.org:beagley-ai = "${BEAGLEY_KERNEL_SRCREV}"
