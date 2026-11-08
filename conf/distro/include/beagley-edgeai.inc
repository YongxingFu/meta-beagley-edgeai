# Use the TI uEnv/Image/DTB boot flow for the two-partition microSD image.
# This also provides a defined place to apply the matching AI overlay.
MACHINE_FEATURES:remove:beagley-ai = "efi"
WKS_FILE:beagley-ai = "sdimage-2part.wks"
PREFERRED_RPROVIDER_ti-edgeai-firmware:beagley-ai = "ti-edgeai-firmware-beagley"
