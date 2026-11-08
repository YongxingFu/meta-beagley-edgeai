# Use the TI uEnv/Image/DTB boot flow for the two-partition microSD image.
# This also provides a defined place to apply the matching AI overlay.
MACHINE_FEATURES:remove:beagley-ai = "efi"
WKS_FILE:beagley-ai = "sdimage-2part.wks"
PREFERRED_RPROVIDER_ti-edgeai-firmware:beagley-ai = "ti-edgeai-firmware-beagley"

# Shared build switches used by kernel fragments and image module packages.
BEAGLEY_ENABLE_MAXIM_GMSL_LEGACY ?= "1"
BEAGLEY_ENABLE_YXMA023EHD ?= "1"
