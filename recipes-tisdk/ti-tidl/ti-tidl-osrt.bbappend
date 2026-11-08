# The TI wheel and C++ archive contain the same SONAME and identical library.
# Share the C++ copy so package dependency scanning sees one provider.
do_install:append:beagley-ai() {
    wheel_lib=${D}${PYTHON_SITEPACKAGES_DIR}/onnxruntime/capi/libonnxruntime.so.1.23.0
    system_lib=${D}${libdir}/libonnxruntime.so.1.23.0
    cmp -s "$wheel_lib" "$system_lib" || bbfatal "ONNX Python and system libraries differ"
    rm "$wheel_lib"
    ln -sr "$system_lib" "$wheel_lib"
}
