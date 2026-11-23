SUMMARY = "TI OX08D10 HDR4 PWL12 ISP tuning"
LICENSE = "TI-TFL"
LIC_FILES_CHKSUM = "file://TI-LICENSE.txt;md5=c77467173484da3377ccbba93f45fa7d"
COMPATIBLE_MACHINE = "^beagley-ai$"
PACKAGE_ARCH = "${MACHINE_ARCH}"
SRC_URI = "file://dcc_viss_wdr.bin file://dcc_2a_wdr.bin file://TI-LICENSE.txt file://PROVENANCE.txt"
S = "${WORKDIR}"
do_install() {
    install -d ${D}/opt/imaging/ox08d10/wdr
    install -m 0644 ${WORKDIR}/dcc*.bin ${D}/opt/imaging/ox08d10/wdr/
    install -m 0644 ${WORKDIR}/TI-LICENSE.txt ${WORKDIR}/PROVENANCE.txt ${D}/opt/imaging/ox08d10/wdr/
}
FILES:${PN} = "/opt/imaging/ox08d10"
