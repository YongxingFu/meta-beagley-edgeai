# Opt-in local Git source, enabled from build/conf/local.conf.
# Fetches a committed revision; uncommitted checkout changes are not built.
BEAGLEY_KERNEL_LOCAL_PATH ?= "${TOPDIR}/../sources/linux-beagley"
BEAGLEY_KERNEL_BRANCH ?= "main"
BEAGLEY_KERNEL_SRCREV ?= "ec3ac72fa78b8dde99087e344248a923f30c2933"

KERNEL_GIT_URI:beagley-ai = "git://${BEAGLEY_KERNEL_LOCAL_PATH}"
KERNEL_GIT_PROTOCOL:beagley-ai = "file"
BRANCH:pn-linux-bb.org:beagley-ai = "${BEAGLEY_KERNEL_BRANCH}"
SRCREV:pn-linux-bb.org:beagley-ai = "${BEAGLEY_KERNEL_SRCREV}"
