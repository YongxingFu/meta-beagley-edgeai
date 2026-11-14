SUMMARY = "OX03H10 sensor-to-HDMI preview service"
DESCRIPTION = "Starts the BeagleY-AI OX03H10 ISP and HDMI preview at boot."
LICENSE = "CLOSED"
PACKAGE_ARCH = "${MACHINE_ARCH}"
COMPATIBLE_MACHINE = "^beagley-ai$"

SRC_URI = " \
    file://ox03h10-hdmi-1080p \
    file://ox03h10-hdmi-preview.service \
    file://ox03h10-msc-release-workaround.c \
"

S = "${WORKDIR}"
B = "${WORKDIR}/build"

inherit systemd

SYSTEMD_SERVICE:${PN} = "ox03h10-hdmi-preview.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += "bash"

do_compile() {
    install -d ${B}
    ${CC} ${CPPFLAGS} ${CFLAGS} -shared -fPIC \
        -o ${B}/ox03h10-msc-release-workaround.so \
        ${WORKDIR}/ox03h10-msc-release-workaround.c ${LDFLAGS}
}

do_install() {
    install -D -m 0755 ${WORKDIR}/ox03h10-hdmi-1080p \
        ${D}${bindir}/ox03h10-hdmi-1080p
    install -D -m 0755 ${B}/ox03h10-msc-release-workaround.so \
        ${D}${libdir}/ox03h10/ox03h10-msc-release-workaround.so
    install -D -m 0644 ${WORKDIR}/ox03h10-hdmi-preview.service \
        ${D}${systemd_system_unitdir}/ox03h10-hdmi-preview.service
}

FILES:${PN} += " \
    ${bindir}/ox03h10-hdmi-1080p \
    ${libdir}/ox03h10/ox03h10-msc-release-workaround.so \
    ${systemd_system_unitdir}/ox03h10-hdmi-preview.service \
"
