/* SPDX-License-Identifier: MIT */
/* Existing TI module releases imported MSC buffers incorrectly on this stack.
 * Keep them owned by the TIOVX graph for this single-process preview.
 */
int tiovx_multi_scaler_module_release_buffers(void *obj)
{
    (void)obj;
    return 0;
}
