# BeagleY-AI TIDL model compatibility

## Summary

The first BeagleY-AI image booted and loaded the TIDL libraries, but the bundled
precompiled models were not compatible with the runtime ABI in the image. The
initial symptom was that TIDL inference returned invalid/zero outputs even
though the application reported that all model nodes were delegated. Replacing
the remote-core firmware fixed a separate IPC startup problem; it did not make
the old model artifacts compatible.

The fix is to compile model artifacts with the TIDL tools that match the
runtime shipped in the image, validate those artifacts on the board, and have
Yocto install the validated artifacts alongside the model and its metadata.
Rebuilding the image without changing the model source/package will reproduce
the mismatch.

## Confirmed findings

- The `edgeai-tidl-models` recipe downloads the TI model zoo release
  `11_02_00` (`EDGEAI_SDK_VERSION=11_02_00`). See
  `meta-edgeai/recipes-tisdk/edgeai-components/edgeai-tidl-models.bb`.
- The `ti-tidl-osrt` recipe fetches the runtime libraries and Python packages
  from `11_02_20_00`. The compiled `ti-tidl` runtime uses the 11.2.x source
  branch. See `meta-edgeai/recipes-tisdk/ti-tidl/ti-tidl-osrt.bb` and
  `meta-edgeai/recipes-tisdk/ti-tidl/ti-tidl.bb`.
- On the board, the old MobileNet model's `*_tidl_io_1.bin` was 378,392 bytes,
  while the installed runtime expected an IO descriptor of 380,952 bytes. The
  runtime logged `Config file size ... does not match size of sTIDL_IOBufDesc_t`.
- Recompiling MobileNet with TI TIDL tools `11_02_20_00` produced a 380,952
  byte IO descriptor and the board completed TIDL inference with a non-zero
  1001-element output. This established the ABI mismatch and proved that
  matching artifacts can execute on the board.
- The on-board YOLOX nano ONNX model is
  `ONR-OD-8200-yolox-nano-lite-mmdet-coco-416x416`. A direct attempt to compile
  all YOLOX nodes as TIDL subgraphs failed with a floating-point exception in
  memory planning. The compiler had partitioned the graph into four TIDL
  subgraphs and left unsupported postprocessing operators on CPU.
- Denying the YOLOX postprocessing nodes from TIDL resulted in one compiled
  C7x subgraph containing 232 nodes. Board inference logged `Ran TIDL graph ...
  Done` and returned bounding boxes; repeated inference measured about 52–63 ms
  per image in the test harness. The artifact set was tested outside Yocto and
  is not yet part of the image.
- The YOLOX model's class prediction is unreliable for the synthetic test
  ball. The prototype intentionally uses only its highest-scoring box for
  localization; this is a demonstration, not a trained ball detector.

## Separate firmware and IPC issue

The original image also had a remote-core communication/startup issue. Rebuilt
R5F/C7x firmware restored RPMsg channels and Vision Apps IPC handshakes. The
tested BeagleY-AI firmware recipe is
`meta-beagley-edgeai/recipes-tisdk/ti-psdk-rtos/ti-edgeai-firmware-beagley_11.02.02.04.bb`.
Model artifacts and remote-core firmware are separate compatibility axes:
both must match the runtime and board memory layout.

The image's Beagle-specific shared-memory mapping is `0x8a0000000`. Firmware,
device tree reservations, Vision Apps userspace and TIDL runtime must continue
to use a consistent memory map.

## DMA-BUF log messages

During YOLOX inference, Vision Apps prints repeated messages similar to:

```text
MEM: ERROR: Buffer may be APP_MEM_HEAP_DDR (local-only, not DMA-heap backed)
MEM: ERROR: Failed to get dmaBufFd for virtPtr ...
```

The board has `/dev/dma_heap/carveout_vision_apps_shared-memories`, so the
device itself is present. TIDL inference and streaming continued during the
observed tests. Follow-up debugging identified the repeated messages as ONNX
tensor eligibility checks and verified the ordinary-buffer fallback; the
targeted fix and its validation are recorded below. Long-run implications of
other DMA errors remain to be checked; strict export failures must not be
hidden. Sustained inference and teardown still need production validation.

## Yocto packaging plan

### DMA-BUF eligibility probe fix (2026-11-08)

The on-board call stack confirmed that ONNX Runtime's
`TIDL_setRtTensorParameters()` calls `TIDLRT_isSharedMem()` for tensor pointers.
Ordinary CPU buffers are valid inputs to this eligibility check, but the
underlying strict DMA-BUF lookup logged an error on every miss. The runtime
then used its existing copying path.

The layer now carries two patches: Vision Apps adds a quiet lookup using the
same locked allocation registry; TIDL uses that lookup to return "not shared"
for unregistered pointers before attempting strict address translation. The
original `appMemGetDmaBufFd()` retains its errors. No pointers are newly marked
shared and the tensor copy/zero-copy selection is unchanged. The TIDL reference
is weak so an older Vision Apps library retains the previous behavior.

Both recipes were rebuilt successfully with `bitbake ti-tidl`. Target checks:

- 100 ordinary-buffer eligibility probes: returned false without DMA errors.
- A TIDL shared allocation: recognized as shared and exported a valid DMA-BUF.
- An explicit strict export of an ordinary pointer: still logged the error.
- YOLOX on one fixed official image, 10 repeated inferences: the old libraries
  logged 50 failed DMA-BUF queries; the patched libraries logged zero. Final
  boxes, scores and labels were identical (maximum absolute difference 0).

The patched libraries were installed on the test board. Original libraries and
`restore.sh` are in `/var/backups/beagley-dmabuf-original/`. Test scripts,
outputs and logs are in `/opt/beagley-ball-demo/dmabuf-fix/`. This fixes noisy
eligibility checks; it does not make NumPy/ONNX allocations zero-copy, and does
not establish long-duration memory stability or model accuracy.

1. Select a supported ONNX/TFLite model and pin its source revision/checksum.
2. Compile on the host with the exact TIDL tools release selected for the
   image runtime. For this bring-up the tested tools were `11_02_20_00` for
   J722S. Store the tools release, SOC, model checksum, compilation options,
   calibration set provenance and generated artifact checksums in metadata.
3. Use representative calibration data and the model's actual preprocessing
   (layout, resize/padding, channel order, input type and normalization).
   Synthetic or random calibration data is suitable only for plumbing tests.
4. Confirm the generated artifacts on the target before packaging: all
   expected subgraphs are present, the runtime accepts the IO descriptors,
   TIDL graph execution succeeds, and output boxes match a CPU/reference
   implementation within a chosen tolerance.
5. Add a Beagle-specific Yocto recipe for model artifacts, or a `.bbappend`
   that replaces the incompatible model-zoo artifacts. Install the model,
   labels/metadata, preprocessing configuration and all TIDL subgraph files as
   one versioned package under `/opt/model_zoo/<model>/`.
6. Ensure package ordering prevents the old model package from overwriting the
   compatible files. Pin `SRCREV`/checksums and bump package `PR` when the
   artifact set changes.
7. Rebuild `tisdk-edgeai-image`, inspect the rootfs package manifest and
   installed artifact checksums, then repeat target inference after flashing.

For YOLOX, preserve the tested `deny_list:layer_name` used to keep the
problematic postprocessing nodes on CPU. Store that setting with the artifact
metadata and pass the same setting to the target runtime. Do not rely on an
implicit compiler default.

## Acceptance checks

- Runtime/model IO descriptor ABI agrees; no descriptor-size mismatch.
- The expected TIDL provider is active and the target log confirms graph
  execution on C7x.
- Input preprocessing matches the model used during compilation.
- Detection boxes and confidence values are plausible across a representative
  range of ball positions; false detections and missed detections are recorded.
- Long-running inference has no hangs, crashes, memory growth or output
  corruption.
- DMA-BUF messages are explained and their fallback behavior is verified.
- The same checks pass using artifacts installed from the generated Yocto
  image, not only manually copied test files.

## Useful test locations

The current board-side prototype and experimental artifacts are under
`/opt/beagley-ball-demo/`. The workstation import logs are in `/tmp/` and are
temporary. These manual test files are not yet Yocto-managed deliverables.
