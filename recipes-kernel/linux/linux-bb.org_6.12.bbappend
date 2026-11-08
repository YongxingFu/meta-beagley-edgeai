FILESEXTRAPATHS:prepend := "${THISDIR}/files:${THISDIR}/../../scripts:"
require yxma023ehd.inc
BEAGLEY_ENABLE_MAXIM_GMSL_LEGACY ?= "1"
SRC_URI:append:beagley-ai = "${@bb.utils.contains('BEAGLEY_ENABLE_MAXIM_GMSL_LEGACY', '1', ' file://beagley-gmsl-legacy.cfg', '', d)}"
KERNEL_CONFIG_FRAGMENTS:append:beagley-ai = "${@bb.utils.contains('BEAGLEY_ENABLE_MAXIM_GMSL_LEGACY', '1', ' ${WORKDIR}/beagley-gmsl-legacy.cfg', '', d)}"
SRC_URI:append:beagley-ai = " file://check-memory-map.py"
DEPENDS:append:beagley-ai = " ti-edgeai-firmware-beagley dtc-native"
KERNEL_DEVICETREE:append:beagley-ai = " ti/k3-am67a-beagley-ai-edgeai-apps.dtbo"
KERNEL_DTC_FLAGS:append:beagley-ai = " -@"

do_configure:prepend:beagley-ai() {
    install -m 0644 ${RECIPE_SYSROOT}${datadir}/beagley-edgeai/beagley-edgeai-memory-map.dtsi ${S}/arch/arm64/boot/dts/ti/
    install -m 0644 ${RECIPE_SYSROOT}${datadir}/beagley-edgeai/k3-am67a-beagley-ai-edgeai-apps.dtso ${S}/arch/arm64/boot/dts/ti/
    if ! grep -q 'k3-am67a-beagley-ai-edgeai-apps.dtbo' ${S}/arch/arm64/boot/dts/ti/Makefile; then
        printf '%s\n' 'dtb-$(CONFIG_ARCH_K3) += k3-am67a-beagley-ai-edgeai-apps.dtbo' >> ${S}/arch/arm64/boot/dts/ti/Makefile
    fi
}

python do_validate_beagley_memory() {
    if d.getVar('MACHINE') != 'beagley-ai':
        return
    import os
    import subprocess
    import sys
    dtbs = os.path.join(d.getVar('B'), 'arch/arm64/boot/dts/ti')
    merged = os.path.join(d.getVar('WORKDIR'), 'beagley-edgeai-memory-validated.dtb')
    subprocess.check_call([
        'fdtoverlay', '-i', os.path.join(dtbs, 'k3-am67a-beagley-ai.dtb'),
        '-o', merged, os.path.join(dtbs, 'k3-am67a-beagley-ai-edgeai-apps.dtbo'),
    ])
    subprocess.check_call([
        sys.executable, os.path.join(d.getVar('WORKDIR'), 'check-memory-map.py'),
        merged, d.getVar('RECIPE_SYSROOT') + d.getVar('datadir') + '/beagley-edgeai/app_mem_map.h',
    ])
}
addtask validate_beagley_memory after do_compile before do_install do_deploy
