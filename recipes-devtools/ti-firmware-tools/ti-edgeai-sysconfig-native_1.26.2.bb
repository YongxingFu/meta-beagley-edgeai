LICENSE = "TI-TFL & MIT & BSD-2-Clause & BSD-3-Clause & Apache-2.0 & ISC & Zlib & CC0-1.0 & MPL-2.0 & Artistic-2.0 & EPL-2.0 & LGPL-2.0-or-later & LGPL-2.1-or-later & APSL-2.0 & PD & CC-BY-4.0 & CC-BY-SA-4.0 & Unlicense"
# The 1.26.2 installer ships this manifest under its existing 1.25.0 filename.
LIC_FILES_CHKSUM = "file://sysconfig_1.26.2/dist/SysConfig_Core_Tool_1.25.0_manifest.html;md5=5c0917fc8a62fb330ca3aca35107dd1c"

require ti-edgeai-tool-native.inc

TI_TOOL_INSTALLER = "sysconfig-1.26.2_4477-setup.run"
TI_TOOL_DIRECTORY = "sysconfig_1.26.2"
TI_TOOL_PREFIX = "${S}/${TI_TOOL_DIRECTORY}"
SRC_URI = "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-nsUM6f7Vvb/1.26.2.4477/${TI_TOOL_INSTALLER}"
SRC_URI[sha256sum] = "9a142af1eabc16dff5105d114163fc2d9cdfb0b213b5139d42f9a80285577e4f"
