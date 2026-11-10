# Opt-in local Git source, enabled from build/conf/local.conf.
# Fetches a committed revision; uncommitted checkout changes are not built.
BEAGLEY_KERNEL_LOCAL_PATH ?= "${TOPDIR}/../sources/linux-beagley"
BEAGLEY_KERNEL_BRANCH ?= "beagley/6.12"
BEAGLEY_KERNEL_SRCREV ?= "0437cebcb1316ba9b7046fc147ce7daa24cced0d"

KERNEL_GIT_URI:beagley-ai = "git://${BEAGLEY_KERNEL_LOCAL_PATH}"
KERNEL_GIT_PROTOCOL:beagley-ai = "file"
BRANCH:pn-linux-bb.org:beagley-ai = "${BEAGLEY_KERNEL_BRANCH}"
SRCREV:pn-linux-bb.org:beagley-ai = "${BEAGLEY_KERNEL_SRCREV}"
