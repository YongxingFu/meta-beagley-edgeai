# Use the same SDK generation as the rebuilt firmware. The upstream Edge AI
# override otherwise selects the older NONSAFETY.11.01.00.03 manifest.
BEAGLEY_REPO_WRAPPER := "${THISDIR}/files/repo-shallow"
FETCHCMD_repo:beagley-ai = "${BEAGLEY_REPO_WRAPPER}"
do_fetch[file-checksums] += "${BEAGLEY_REPO_WRAPPER}:True"
SRC_URI:beagley-ai:edgeai = "repo://git.ti.com/git/processor-sdk/psdk_repo_manifests.git;protocol=https;branch=refs/tags/REL.PSDK.ANALYTICS.11.02.02.07;manifest=vision_apps_yocto.xml"
DEPENDS:append:beagley-ai = " ti-edgeai-firmware-beagley nlohmann-json stb"
EXTRA_OEMAKE:append:beagley-ai = " TISDK_IMAGE=edgeai"
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append:beagley-ai = " file://0002-mem-add-quiet-dmabuf-probe.patch;patchdir=${WORKDIR}/repo"

do_compile:prepend:beagley-ai() {
    # The 11.02 SDK requests these two demos in yocto_build, but its
    # Edge AI directory list omits their source directory.
    sed -i -e "/^DIRECTORIES += apps\/basic_demos\/app_fd_exchange$/d" -e "/DIRECTORIES += apps\/basic_demos\/app_c7x_kernel/a DIRECTORIES += apps/basic_demos/app_fd_exchange" ${WORKDIR}/repo/vision_apps/Makefile
    install -m 0644 ${RECIPE_SYSROOT}${datadir}/beagley-edgeai/app_mem_map.h ${WORKDIR}/repo/vision_apps/platform/j722s/rtos/app_mem_map.h
    if [ -f ${WORKDIR}/repo/psdk_include/vision_apps/platform/j722s/rtos/app_mem_map.h ]; then
        install -m 0644 ${RECIPE_SYSROOT}${datadir}/beagley-edgeai/app_mem_map.h ${WORKDIR}/repo/psdk_include/vision_apps/platform/j722s/rtos/app_mem_map.h
    fi
}
