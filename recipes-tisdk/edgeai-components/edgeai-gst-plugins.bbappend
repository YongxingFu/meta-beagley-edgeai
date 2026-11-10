FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append:beagley-ai = " file://0003-enable-j722s-tiovxisp.patch"
SRC_URI:append:beagley-ai = " file://0006-skip-ti-2a-when-disabled.patch"
SRC_URI:append:beagley-ai = " file://0007-zero-copy-dmabuf-import.patch"
