SUMMARY = "TI host tool for rebuilding BeagleY-AI Edge AI firmware"
HOMEPAGE = "https://www.ti.com/"

inherit native

COMPATIBLE_HOST = "x86_64.*-linux"
S = "${WORKDIR}/vendor-tools"
TI_TOOL_PREFIX ?= "${S}"

# Current TI installers are 64-bit InstallBuilder binaries. The older
# meta-ti ti-unpack helper targets 32-bit InstallJammer and is unsuitable.
python do_unpack:append() {
    import os
    import subprocess
    os.makedirs(d.getVar('S'), exist_ok=True)
    installer = os.path.join(d.getVar('WORKDIR'), d.getVar('TI_TOOL_INSTALLER'))
    os.chmod(installer, 0o755)
    subprocess.check_call([installer, '--mode', 'unattended', '--prefix', d.getVar('TI_TOOL_PREFIX')])
}

do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${libdir}/beagley-firmware-tools
    cp -R --preserve=mode,links ${S}/${TI_TOOL_DIRECTORY} ${D}${libdir}/beagley-firmware-tools/
}

INHIBIT_SYSROOT_STRIP = "1"
