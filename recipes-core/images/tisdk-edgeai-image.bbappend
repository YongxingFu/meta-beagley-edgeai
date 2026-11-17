EDGEAI_STACK:remove:beagley-ai = "ti-edgeai-firmware"
EDGEAI_STACK:append:beagley-ai = " ti-edgeai-firmware-beagley"

# Include the camera drivers in the image. A camera overlay is still required
# to describe the board wiring and the sensor's configured output mode.
IMAGE_INSTALL:append:beagley-ai = " ${@bb.utils.contains('BEAGLEY_ENABLE_MAXIM_GMSL_LEGACY', '1', 'kernel-module-max96716a kernel-module-max96717 kernel-module-ox03h10', '', d)} ${@bb.utils.contains('BEAGLEY_ENABLE_YXMA023EHD', '1', 'kernel-module-panel-yousee-yxma023ehd', '', d)}"
IMAGE_INSTALL:append:beagley-ai = " kernel-module-panel-lvds"
IMAGE_INSTALL:append:beagley-ai = " ${@bb.utils.contains('BEAGLEY_ENABLE_OX03H10_CAMERA', '1', 'ox03h10-hdmi-preview', '', d)}"

IMAGE_INSTALL:append:beagley-ai = " kernel-module-ox08d10"
