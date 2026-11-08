SUMMARY = "Edge AI R5F and C7x firmware built for BeagleY-AI 4 GiB RAM"
LICENSE = "TI-TFL & BSD-2-Clause & BSD-3-Clause & MIT & Apache-2.0-with-LLVM-exception & BSL-1.0 & PD"
LIC_FILES_CHKSUM = "file://psdk_rtos/PROCESSOR_SDK_RTOS_J722S_manifest.html;md5=5590fc0ddeef4970e8a853aeb2d17770"

COMPATIBLE_MACHINE = "^beagley-ai$"
PACKAGE_ARCH = "${MACHINE_ARCH}"
INHIBIT_DEFAULT_DEPS = "1"

inherit python3native ti-secdev update-alternatives

DEPENDS += "ti-edgeai-c7000-native ti-edgeai-armllvm-native ti-edgeai-sysconfig-native"

SRC_URI = " \
    https://dr-download.ti.com/software-development/software-development-kit-sdk/MD-1bSfTnVt5d/11.02.02.04/ti-processor-sdk-rtos-j722s-evm-11_02_02_04.tar.gz \
    file://0001-j722s-use-BeagleY-AI-memory-layout.patch \
    file://k3-am67a-beagley-ai-edgeai-apps.dtso \
"
SRC_URI[sha256sum] = "c176a4599e8c702bdae6c955c108699ccefbaaf3d1523c530ef60d31c3dd8105"
S = "${WORKDIR}/ti-processor-sdk-rtos-j722s-evm-11_02_02_04"
B = "${S}/sdk_builder"

FIRMWARE_TOOLS = "${STAGING_LIBDIR_NATIVE}/beagley-firmware-tools"
MCU_PLUS_SDK = "${S}/mcu_plus_sdk_j722s_11_02_02_06"

EXTRA_OEMAKE = " \
    --no-print-directory NUM_THREADS=4 \
    SOC=j722s TISDK_IMAGE=edgeai PROFILE=release RTOS=FREERTOS \
    BUILD_EMULATION_MODE=no BUILD_LINUX_MPU=no BUILD_QNX_MPU=no \
    BUILD_CPU_MPU1=no BUILD_APP_RTOS_LINUX=yes BUILD_APP_RTOS_QNX=no \
    ENABLED_IPC_CORES='ENABLE_IPC_MPU1 ENABLE_IPC_MCU2_0 ENABLE_IPC_C7x_1 ENABLE_IPC_C7x_2' \
    PSDK_TOOLS_PATH=${FIRMWARE_TOOLS} TOOLS_PATH=${FIRMWARE_TOOLS} \
    TIARMCGT_LLVM_ROOT=${FIRMWARE_TOOLS}/ti-cgt-armllvm_4.0.4.LTS \
    CGT7X_ROOT=${FIRMWARE_TOOLS}/ti-cgt-c7000_5.0.0.LTS \
    SYSCFG_PATH=${FIRMWARE_TOOLS}/sysconfig_1.26.2 \
    SYSCFG_NODE=${FIRMWARE_TOOLS}/sysconfig_1.26.2/nodejs/node \
    SYSCFG_CLI_PATH=${FIRMWARE_TOOLS}/sysconfig_1.26.2 \
    MCU_PLUS_SDK_PATH=${MCU_PLUS_SDK} \
    MCU_PLUS_SDK_INSTALL_PATH=${MCU_PLUS_SDK} \
    TI_SECURE_DEV_PKG=${TI_SECURE_DEV_PKG} \
"
PARALLEL_MAKE = "-j 4"

do_configure() {
    oe_runmake -C ${S}/sdk_builder/scripts get_component_versions > ${T}/component-versions.log
    sed -n '/^export [A-Z_][A-Z_0-9]*=/p' ${T}/component-versions.log > ${S}/.component_versions_j722s_env
    test -s ${S}/.component_versions_j722s_env
    cd ${S}/vision_apps/platform/j722s/rtos
    PYTHONPATH=${S}/vision_apps/tools/PyTI_PSDK_RTOS ${PYTHON} gen_linker_mem_map.py
}

python do_prepare_firmware_sdk() {
    import pathlib
    root = pathlib.Path(d.getVar('S')) / 'sdk_builder/makerules'

    def replace(path, before, after):
        text = path.read_text()
        if before not in text:
            if after in text:
                return
            bb.fatal('Unexpected SDK build rule in %s' % path)
        if text.count(before) != 1:
            bb.fatal('Ambiguous SDK build rule in %s' % path)
        path.write_text(text.replace(before, after))

    # Keep each remote core's address translation aligned with the generated
    # Beagle DDR_SHARED_MEM_PHYS_ADDR, not the TI EVM's 0x900000000 mapping.
    import re
    source = pathlib.Path(d.getVar('S'))
    rtos = source / 'vision_apps/platform/j722s/rtos'
    header = (rtos / 'app_mem_map.h').read_text()
    match = re.search(r'^#define\s+DDR_SHARED_MEM_PHYS_ADDR\s+\((0x[0-9A-Fa-f]+)u\)', header, re.MULTILINE)
    if not match:
        bb.fatal('Missing generated DDR_SHARED_MEM_PHYS_ADDR')
    shared_addr = match.group(1)
    for rel in ['mcu2_0/freertos_no_board_deps.syscfg',
                'c7x_1/freertos.syscfg', 'c7x_2/freertos.syscfg']:
        replace(rtos / rel, '0x900000000', shared_addr)

    # The vendor "no board deps" R5 config still enables the EVM Ethernet
    # firmware and a second UDMA instance; its initialization stalls on
    # BeagleY-AI. Keep the single UDMA instance required by vision apps.
    r5cfg = rtos / 'mcu2_0/freertos_no_board_deps.syscfg'
    text = r5cfg.read_text()
    declaration = 'const enet_cpsw   = scripting.addModule("/networking/enet_cpsw/enet_cpsw", {}, false);\nconst enet_cpsw1  = enet_cpsw.addInstance();\n'
    start = 'enet_cpsw1.$name'
    udma = 'const udma       = scripting.addModule("/drivers/udma/udma", {}, false);\nconst udma1      = udma.addInstance();\n'
    if declaration in text and text.count(start) == 1 and text.count(udma) == 1:
        text = text.replace(declaration, '')
        text = text[:text.index(start)] + udma
        r5cfg.write_text(text)
    elif 'enet_cpsw' in text or text.count(udma) != 1:
        bb.fatal('Unexpected R5 SysConfig layout in %s' % r5cfg)

    # Only R5F has a no-board-dependencies SysConfig variant. The C7x cores
    # use the regular RTOS configuration, which has no board pin setup.
    path = root / 'makefile_vision_apps.mak'
    for core in ['c7x_1', 'c7x_2']:
        replace(path, '/rtos/' + core + '/$(MCU_SYSCFG_FILE)',
                '/rtos/' + core + '/$(RTOS_TYPE).syscfg')

    path = root / 'makefile_tidl_mmalib.mak'
    # Keep the vendor build inside this laptop's firmware parallelism limit.
    replace(path, 'NUM_THREADS := $(shell nproc --ignore=2)', 'NUM_THREADS := 4')
    # The generic SDK target otherwise invokes an empty ARM target even when
    # the firmware-only build explicitly disables the Linux MPU core.
    before = '$(MAKE) -C $(TIDL_PATH)/arm-tidl tidl_tiovx_arm_kernels TARGET_BUILD=$(current_profile);'
    after = 'if [ "$(BUILD_CPU_MPU1)" = "yes" ]; then ' + before + ' fi;'
    text = path.read_text()
    if after not in text:
        replace(path, before, after)
}
addtask prepare_firmware_sdk after do_configure before do_compile

do_compile() {
    # This task builds only R5F/C7x firmware. Linux userspace is built by the
    # regular Yocto recipes, using the same generated header via the sysroot.
    unset CC CXX LD AR AS STRIP CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
    oe_runmake -C ${B} sdk
    grep -Fxq ENABLE_IPC_MPU1 ${S}/vision_apps/.build_core.bak || bbfatal "Linux MPU1 missing from firmware IPC core list"
}

python do_install() {
    import pathlib
    import re
    import shutil
    import subprocess

    source = pathlib.Path(d.getVar('S'))
    dest = pathlib.Path(d.getVar('D'))
    firmware_dir = d.getVar('nonarch_base_libdir') + '/firmware/beagley_edgeai'
    firmware_dest = dest / firmware_dir.lstrip('/')
    firmware_dest.mkdir(parents=True, exist_ok=True)
    signer = pathlib.Path(d.getVar('TI_SECURE_DEV_PKG')) / 'scripts/secure-binary-image.sh'
    for name in ['vx_app_rtos_linux_mcu2_0.out', 'vx_app_rtos_linux_c7x_1.out', 'vx_app_rtos_linux_c7x_2.out']:
        matches = list((source / 'vision_apps/out').glob('**/FREERTOS/release/' + name))
        if len(matches) != 1:
            bb.fatal('Expected exactly one release firmware for %s, found %s' % (name, matches))
        shutil.copy2(matches[0], firmware_dest / name)
        subprocess.check_call([str(signer), str(matches[0]), str(firmware_dest / (name + '.signed'))])

    data_dest = dest / d.getVar('datadir').lstrip('/') / 'beagley-edgeai'
    data_dest.mkdir(parents=True, exist_ok=True)
    maps = source / 'vision_apps/platform/j722s/rtos'
    shutil.copy2(maps / 'app_mem_map.h', data_dest / 'app_mem_map.h')
    text = (maps / 'k3-j722s-rtos-memory-map.dtsi').read_text()
    # The vendor-generated introduction contains "linux*/arch", ending its
    # comment early. Export the node declarations without that introduction.
    start = re.search(r'(?m)^[ \t]*vision_apps_mcu_r5fss0_core0_dma_memory_region:', text)
    if not start:
        bb.fatal('Cannot locate generated memory reservations')
    (data_dest / 'beagley-edgeai-memory-map.dtsi').write_text(text[start.start():])
    shutil.copy2(pathlib.Path(d.getVar('WORKDIR')) / 'k3-am67a-beagley-ai-edgeai-apps.dtso', data_dest)
    shutil.copy2(source / 'psdk_rtos/PROCESSOR_SDK_RTOS_J722S_manifest.html', data_dest)
}

ALTERNATIVE:${PN} = "j722s-main-r5f0_0-fw j722s-c71_0-fw j722s-c71_1-fw j722s-main-r5f0_0-fw-sec j722s-c71_0-fw-sec j722s-c71_1-fw-sec"
ALTERNATIVE_PRIORITY = "100"
ALTERNATIVE_LINK_NAME[j722s-main-r5f0_0-fw] = "${nonarch_base_libdir}/firmware/j722s-main-r5f0_0-fw"
ALTERNATIVE_LINK_NAME[j722s-c71_0-fw] = "${nonarch_base_libdir}/firmware/j722s-c71_0-fw"
ALTERNATIVE_LINK_NAME[j722s-c71_1-fw] = "${nonarch_base_libdir}/firmware/j722s-c71_1-fw"
ALTERNATIVE_LINK_NAME[j722s-main-r5f0_0-fw-sec] = "${nonarch_base_libdir}/firmware/j722s-main-r5f0_0-fw-sec"
ALTERNATIVE_LINK_NAME[j722s-c71_0-fw-sec] = "${nonarch_base_libdir}/firmware/j722s-c71_0-fw-sec"
ALTERNATIVE_LINK_NAME[j722s-c71_1-fw-sec] = "${nonarch_base_libdir}/firmware/j722s-c71_1-fw-sec"
ALTERNATIVE_TARGET[j722s-main-r5f0_0-fw] = "${nonarch_base_libdir}/firmware/beagley_edgeai/vx_app_rtos_linux_mcu2_0.out"
ALTERNATIVE_TARGET[j722s-c71_0-fw] = "${nonarch_base_libdir}/firmware/beagley_edgeai/vx_app_rtos_linux_c7x_1.out"
ALTERNATIVE_TARGET[j722s-c71_1-fw] = "${nonarch_base_libdir}/firmware/beagley_edgeai/vx_app_rtos_linux_c7x_2.out"
ALTERNATIVE_TARGET[j722s-main-r5f0_0-fw-sec] = "${nonarch_base_libdir}/firmware/beagley_edgeai/vx_app_rtos_linux_mcu2_0.out.signed"
ALTERNATIVE_TARGET[j722s-c71_0-fw-sec] = "${nonarch_base_libdir}/firmware/beagley_edgeai/vx_app_rtos_linux_c7x_1.out.signed"
ALTERNATIVE_TARGET[j722s-c71_1-fw-sec] = "${nonarch_base_libdir}/firmware/beagley_edgeai/vx_app_rtos_linux_c7x_2.out.signed"

RPROVIDES:${PN} += "ti-edgeai-firmware"
FILES:${PN} += "${nonarch_base_libdir}/firmware ${datadir}/beagley-edgeai"
SYSROOT_DIRS += "${datadir}/beagley-edgeai"
INHIBIT_PACKAGE_STRIP = "1"
INHIBIT_SYSROOT_STRIP = "1"
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
INSANE_SKIP:${PN} += "arch"
