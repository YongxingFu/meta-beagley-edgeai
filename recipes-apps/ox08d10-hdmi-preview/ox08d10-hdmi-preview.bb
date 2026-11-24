SUMMARY = "OX08D10 hardware ISP center-crop preview on HDMI"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
COMPATIBLE_MACHINE = "^beagley-ai$"
PACKAGE_ARCH = "${MACHINE_ARCH}"
SRC_URI = "file://ox08d10-hdmi-1080p file://ox08d10-msc-workaround.c"
S = "${WORKDIR}"
B = "${WORKDIR}/build"
RDEPENDS:${PN} += "ox08d10-tuning edgeai-gst-plugins edgeai-tiovx-modules v4l-utils gstreamer1.0 gstreamer1.0-plugins-bad-kms gstreamer1.0-plugins-bad-debugutilsbad"

do_compile() {
    install -d ${B}
    ${CC} ${CPPFLAGS} ${CFLAGS} -shared -fPIC ${WORKDIR}/ox08d10-msc-workaround.c -o ${B}/msc-workaround.so ${LDFLAGS}
}
do_install() {
    install -D -m 0755 ${WORKDIR}/ox08d10-hdmi-1080p ${D}${bindir}/ox08d10-hdmi-1080p
    install -D -m 0755 ${B}/msc-workaround.so ${D}${libdir}/ox08d10/msc-workaround.so
}
FILES:${PN} += "${libdir}/ox08d10/msc-workaround.so"
