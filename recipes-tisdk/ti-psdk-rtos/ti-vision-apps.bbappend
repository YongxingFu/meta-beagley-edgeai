# Use the same SDK generation as the rebuilt firmware. The upstream Edge AI
# override otherwise selects the older NONSAFETY.11.01.00.03 manifest.
BEAGLEY_REPO_WRAPPER := "${THISDIR}/files/repo-shallow"
FETCHCMD_repo:beagley-ai = "${BEAGLEY_REPO_WRAPPER}"
do_fetch[file-checksums] += "${BEAGLEY_REPO_WRAPPER}:True"
SRC_URI:beagley-ai:edgeai = "repo://git.ti.com/git/processor-sdk/psdk_repo_manifests.git;protocol=https;branch=refs/tags/REL.PSDK.ANALYTICS.11.02.02.07;manifest=vision_apps_yocto.xml"
DEPENDS:append:beagley-ai = " ti-edgeai-firmware-beagley nlohmann-json stb"
EXTRA_OEMAKE:append:beagley-ai = " TISDK_IMAGE=edgeai"
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
FILES:${PN}:append:beagley-ai = " ${bindir}/ox03h10-stream ${bindir}/ox03h10-lcd-preview ${datadir}/ox03h10"
SRC_URI:append:beagley-ai = " file://0002-mem-add-quiet-dmabuf-probe.patch;patchdir=${WORKDIR}/repo"
SRC_URI:append:beagley-ai = " file://0003-j722s-link-ti-2a-wrapper.patch;patchdir=${WORKDIR}/repo"
SRC_URI:append:beagley-ai = " file://0004-dcc-support-20-photospace-regions.patch;patchdir=${WORKDIR}/repo"
SRC_URI:append:beagley-ai = " file://0005-ti-2a-honor-explicit-modes.patch;patchdir=${WORKDIR}/repo"
SRC_URI:append:beagley-ai = " file://0006-ox03h10-pre-wb-zero-guard.patch;patchdir=${WORKDIR}/repo"
SRC_URI:append:beagley-ai = " \
    file://dcc/ox03h10/wdr/dcc_2a_wdr_304.bin \
    file://dcc/ox03h10/wdr/dcc_viss_wdr_304.bin \
    file://normalize-ox03h10-dcc.py \
    file://ox03h10-stream.sh \
    file://ox03h10-lcd-preview.sh \
    file://ox03h10-receive.sh \
    file://ox03h10-restart-test.sh \
    file://ox03h10-endurance-test.sh \
"

do_compile:prepend:beagley-ai() {
    # The 11.02 SDK requests these two demos in yocto_build, but its
    # Edge AI directory list omits their source directory.
    sed -i -e "/^DIRECTORIES += apps\/basic_demos\/app_fd_exchange$/d" -e "/DIRECTORIES += apps\/basic_demos\/app_c7x_kernel/a DIRECTORIES += apps/basic_demos/app_fd_exchange" ${WORKDIR}/repo/vision_apps/Makefile
    install -m 0644 ${RECIPE_SYSROOT}${datadir}/beagley-edgeai/app_mem_map.h ${WORKDIR}/repo/vision_apps/platform/j722s/rtos/app_mem_map.h
    if [ -f ${WORKDIR}/repo/psdk_include/vision_apps/platform/j722s/rtos/app_mem_map.h ]; then
        install -m 0644 ${RECIPE_SYSROOT}${datadir}/beagley-edgeai/app_mem_map.h ${WORKDIR}/repo/psdk_include/vision_apps/platform/j722s/rtos/app_mem_map.h
    fi
}

do_install:append() {
    if [ "${MACHINE}" = "beagley-ai" ]; then
        ${PYTHON} ${WORKDIR}/normalize-ox03h10-dcc.py ${WORKDIR} ${D}
        install -D -m 0755 ${WORKDIR}/ox03h10-stream.sh ${D}${bindir}/ox03h10-stream
        install -D -m 0755 ${WORKDIR}/ox03h10-lcd-preview.sh ${D}${bindir}/ox03h10-lcd-preview
        install -D -m 0755 ${WORKDIR}/ox03h10-receive.sh ${D}${datadir}/ox03h10/ox03h10-receive
        install -D -m 0755 ${WORKDIR}/ox03h10-restart-test.sh ${D}${datadir}/ox03h10/ox03h10-restart-test
        install -D -m 0755 ${WORKDIR}/ox03h10-endurance-test.sh ${D}${datadir}/ox03h10/ox03h10-endurance-test
    fi
}
