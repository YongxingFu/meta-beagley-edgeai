# Experimental compile-only selection. Do not use as a board-qualified BSP.
BEAGLEY_KERNEL_LOCAL_PATH ?= "${TOPDIR}/../sources/linux-beagley"
BEAGLEY_KERNEL_BRANCH = "feature/maxim-gmsl2"
BEAGLEY_KERNEL_SRCREV = "64f75630fdf1220bc1e1ff4391a0bbf6296ddf63"
BEAGLEY_ENABLE_MAXIM_GMSL = "1"
KERNEL_GIT_URI:beagley-ai = "git://${BEAGLEY_KERNEL_LOCAL_PATH}"
KERNEL_GIT_PROTOCOL:beagley-ai = "file"
BRANCH:beagley-ai = "${BEAGLEY_KERNEL_BRANCH}"
SRCREV:pn-linux-bb.org:beagley-ai = "${BEAGLEY_KERNEL_SRCREV}"
