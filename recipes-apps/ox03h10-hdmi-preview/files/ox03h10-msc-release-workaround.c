/*
 * Workaround for edgeai-tiovx-modules 1.0.0 invalid free in
 * tiovx_multi_scaler_module_release_buffers(). Returning VX_SUCCESS is safe for
 * the single-process scaler preview and avoids a startup abort.
 */
int tiovx_multi_scaler_module_release_buffers(void *obj)
{
    (void)obj;
    return 0;
}
