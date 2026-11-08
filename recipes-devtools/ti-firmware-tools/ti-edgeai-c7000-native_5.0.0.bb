LICENSE = "TI-TFL & BSL-1.0 & Patrick-Powell & BSD-3-Clause & Hewlett-Packard & MIT & BSD-2-Clause & PD"
LIC_FILES_CHKSUM = "file://ti-cgt-c7000_5.0.0.LTS/C7000_Code_Generation_Tools_C7000-CGT-5_manifest.html;md5=997b07e861cdfda58f7f549d16433ef5"

require ti-edgeai-tool-native.inc

TI_TOOL_INSTALLER = "ti_cgt_c7000_5.0.0.LTS_linux-x64_installer.bin"
TI_TOOL_DIRECTORY = "ti-cgt-c7000_5.0.0.LTS"
SRC_URI = "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-707zYe3Rik/5.0.0.LTS/${TI_TOOL_INSTALLER}"
SRC_URI[sha256sum] = "00679f852732ad23cea97e6fa3648d7c2d9aca26c244451e8b07a91c1d20ee7f"
