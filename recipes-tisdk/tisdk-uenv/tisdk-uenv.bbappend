FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# The foundational layer requests the EVM/SK extra environment for every J722S.
# BeagleY-AI supplies its own environment instead.
SRC_URI:remove:beagley-ai = "file://uEnv-sk.txt"

do_deploy:beagley-ai() {
    install -d ${DEPLOYDIR}
    install -m 0644 ${S}/uEnv.txt ${DEPLOYDIR}/uEnv.txt
}
