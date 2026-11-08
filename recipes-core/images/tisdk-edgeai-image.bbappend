EDGEAI_STACK:remove:beagley-ai = "ti-edgeai-firmware"
EDGEAI_STACK:append:beagley-ai = " ti-edgeai-firmware-beagley"

# Include the development drivers in the TF-card image, without auto-probing
# hardware whose board wiring/register profiles are not configured yet.
IMAGE_INSTALL:append:beagley-ai = " ${@bb.utils.contains('BEAGLEY_ENABLE_MAXIM_GMSL_LEGACY', '1', 'kernel-module-max96716a kernel-module-max96717 kernel-module-ovx3h', '', d)} ${@bb.utils.contains('BEAGLEY_ENABLE_YXMA023EHD', '1', 'kernel-module-panel-yousee-yxma023ehd', '', d)}"
