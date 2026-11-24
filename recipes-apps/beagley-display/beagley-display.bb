SUMMARY = "BeagleY OLED and OX08D10 display prototype"
LICENSE = "CLOSED"
COMPATIBLE_MACHINE = "^beagley-ai$"
PACKAGE_ARCH = "${MACHINE_ARCH}"

# Local working-tree build. Set BEAGLEY_DISPLAY_SOURCE for another checkout.
BEAGLEY_DISPLAY_SOURCE ?= "${TOPDIR}/../sources/beagley-ai-apps/beagley-display-app"
EXTERNALSRC = "${BEAGLEY_DISPLAY_SOURCE}"
EXTERNALSRC_BUILD = "${WORKDIR}/build"

inherit cmake pkgconfig systemd externalsrc

DEPENDS = "gstreamer1.0 glib-2.0 libdrm"
RDEPENDS:${PN} += "gstreamer1.0 gstreamer1.0-plugins-base-videoconvertscale gstreamer1.0-plugins-good-png gstreamer1.0-plugins-good-imagefreeze gstreamer1.0-plugins-bad-kms edgeai-gst-plugins edgeai-tiovx-modules v4l-utils ox08d10-tuning ox08d10-hdmi-preview"
EXTRA_OECMAKE += "-DSYSTEMD_SYSTEM_UNIT_DIR=${systemd_system_unitdir}"
SYSTEMD_SERVICE:${PN} = "beagley-oled.service beagley-camera.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"
CONFFILES:${PN} += "${sysconfdir}/beagley-display/display.ini"
