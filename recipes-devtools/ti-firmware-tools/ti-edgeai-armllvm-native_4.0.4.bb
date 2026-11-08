LICENSE = "TI-TFL & Apache-2.0-with-LLVM-exception & MIT & BSD-2-Clause & BSD-3-Clause & BSD-4-Clause & PD & Patrick-Powell & BSL-1.0"
# The vendor's 4.0.4 bundle retains the 4.0.3 manifest filename.
LIC_FILES_CHKSUM = "file://ti-cgt-armllvm_4.0.4.LTS/TI_Arm_Clang_Compiler_4.0.3_manifest.html;md5=2258a4736616c06a0f029335cabccf4c"

require ti-edgeai-tool-native.inc

TI_TOOL_INSTALLER = "ti_cgt_armllvm_4.0.4.LTS_linux-x64_installer.bin"
TI_TOOL_DIRECTORY = "ti-cgt-armllvm_4.0.4.LTS"
SRC_URI = "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-ayxs93eZNN/4.0.4.LTS/${TI_TOOL_INSTALLER}"
SRC_URI[sha256sum] = "98c60ecc259a07a54be6fcc0f55990332f493bfe5dad460c0ba83963f5dcb06f"
