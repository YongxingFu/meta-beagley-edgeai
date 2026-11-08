# Driver and overlay sources live in the default beagley/6.12 kernel branch.
# Build by default; the overlay is not activated at boot.
BEAGLEY_ENABLE_YXMA023EHD ?= "1"

SRC_URI:append:beagley-ai = "${@bb.utils.contains('BEAGLEY_ENABLE_YXMA023EHD', '1', ' file://yxma023ehd.cfg', '', d)}"
KERNEL_CONFIG_FRAGMENTS:append:beagley-ai = "${@bb.utils.contains('BEAGLEY_ENABLE_YXMA023EHD', '1', ' ${WORKDIR}/yxma023ehd.cfg', '', d)}"
KERNEL_DEVICETREE:append:beagley-ai = "${@bb.utils.contains('BEAGLEY_ENABLE_YXMA023EHD', '1', ' ti/k3-am67a-beagley-ai-yxma023ehd.dtbo', '', d)}"
