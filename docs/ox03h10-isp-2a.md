# OX03H10 ISP/2A integration handoff

This note records the OX03H10 ISP and 2A parameters carried over from the J722S
ADAS SDK debugging baseline and the planned BeagleY-AI adaptation. The reference
uses the same sensor and J722S VPAC ISP, but its ADAS camera-service control
path is not present in the BeagleY-AI Edge AI stack. Treat inherited register
behavior and tuning as a reference to validate on the target, not as proof that
the Linux controls or closed-loop 2A are working on this board.

The items below describe implementation inputs and code paths. Board-level
validation of sensor control writes, image response, AE convergence, and AWB
color response remains open unless a result is explicitly recorded here.

## DCC profile

The camera uses DCC camera module ID 304 and these supplied profiles:

- `dcc_viss_wdr_304.bin`: VISS/PWL/H3A parameters
- `dcc_2a_wdr_304.bin`: TI3 AWB tuning and H3A layout

The supplied artifacts carry a project-specific big-endian zlib CRC32 trailer.
`normalize-ox03h10-dcc.py` verifies that trailer and installs the trailer-free
TI DCC bytes, the original artifact, and the checksum sidecar. The VISS parser
supports the profile's 20 RGB2RGB photospace regions.

OX03H10 outputs one 1920x1536 RAW12 frame at 60 fps. The sensor combines its
internal HCG/LCG/SPD/LOFIC captures and compresses the wide-dynamic-range result
with PWL. VISS must retain the supplied decompand LUT; changing one side of the
compress/decompress pair changes image brightness and contrast.

## ADAS exposure program

The J722S ADAS OX03H10 driver uses a three-stage program:

1. Exposure 2000 to 10000 us, analog gain 1228 Q10 (approximately 1.2x), digital gain 256 Q8 (1x).
2. Exposure 10000 us, analog gain 1228 to 15872 Q10, digital gain 256 Q8.
3. Exposure 10000 us, analog gain 15872 Q10, digital gain 256 to 768 Q8 (up to 3x).

Brightness is target 50, range 45 to 55, threshold 2. Exposure step is one and
backlight compensation is disabled.

For this mode the ADAS reference uses `SCLK=100 MHz` and total HTS 2047. Exposure
input in microseconds is converted to double-row units with:

```text
explines = exposure_us * 100 / 2047
explines = clamp(explines, 2, 802)
```

The Linux exposure control therefore uses line units in that range. TI Q10 analog
gain is converted to the sensor 4.4 code with rounding and clamped from 19 to 248.
Digital gain remains Q8 and is clamped from 256 to 768.

## Sensor control mapping

### Exposure

The Linux driver writes both exposure channels together:

- DCG/HCG: `0x3501`, `0x3502`
- SPD/LOFIC: `0x3541`, `0x3542`

HCG is the dynamic AE object. SPD exposure follows HCG. LCG and LOFIC analog
gains stay at the fixed values from the ADAS reference initialization sequence.

### Analog gain

HCG analog gain is written to:

- `0x3508`: integer and high fractional nibble
- `0x3509`: low fractional nibble in bits 7:4

The sensor uses a 4.4 encoding: 16 is 1x and 248 is 15.5x.

### Digital/inverse gain

The ADAS reference implementation uses the four register pairs at `0x5da0` through
`0x5da7` as an equal per-channel digital-gain path. The OX03H10 datasheet names
these registers manual AWB inverse gain. Preserve this reference behavior and
set all four pairs to the same converted value; do not reinterpret them as the
exposure-channel digital gain registers merely from the datasheet label. Q8 input
is converted to the register's Q10 form with `value = gain * 2`, then split as
`high = value >> 7` and `low = (value << 1) & 0xff`. Bit 0 of `0x5da8` enables
the manual inverse-gain path.

The exposure-channel digital gain registers in the datasheet (`0x350a/b/c` and
corresponding channel variants) are not used by this first AE port.

## Current-stack adaptation

The `edgeai-gst-plugins` patch set adds `SENSOR_OX03H10` handling, the ADAS
exposure program, and mappings from TI 2A output to Linux controls:

- `V4L2_CID_EXPOSURE`: double-row exposure units
- `V4L2_CID_ANALOGUE_GAIN`: sensor 4.4 gain code
- `V4L2_CID_GAIN`: Q8 digital/inverse gain

Automatic mode passes the selected subdevice to the ISP sink pad with
`sink_0::device=...`. `ox03h10-stream` can select a unique `/dev/v4l-subdev*`
candidate by the presence of `exposure`, `analogue_gain`, and `gain` controls.
This is only a control-presence heuristic: it does not identify the sensor, so
verify the selected device against `media-ctl -p` and use `-s` or
`SENSOR_SUBDEV` to select it explicitly when possible. A unique candidate may
still belong to another sensor. Fixed-parameter mode disables host AE/AWB and
does not need the subdevice path.

## Validation order

1. Confirm subdevice identity through the media graph, then list controls and
   verify the ranges against the driver implementation.
2. With streaming stopped, change one control at a time and confirm register
   readback using the board's supported register access method. The addresses
   listed above are inherited from the ADAS reference; confirm their meaning
   for the active sensor mode before interpreting readback.
3. Keep AWB disabled and sweep exposure 2, 5, 10, and 15 ms; record requested
   control values, register values, and captured image response.
4. Keep exposure fixed and sweep analog gain 1.2x, 4x, 8x, and 15.5x; record
   the same evidence and check for clipping or non-monotonic response.
5. Enable AE only after fixed-step behavior is repeatable and monotonic. Record
   convergence and stability separately from successful pipeline startup.

The TI 2A wrapper code passes `sensor_pre_wb_gain=1` for OX03H10. Its previous
gains are initialized from the sensor's HCG WB registers (converted from Q10 to
TI's Q9 convention: B=991, G=512, R=1083). The state remains the sensor-side
gain because this port continues to apply AWB results in VISS. A zero-divisor
fallback to unity is also present in the wrapper. Automatic AWB still needs
board validation with a neutral target before being considered complete. No
closed-loop AE/AWB result is established by this handoff note alone.
