# OX03H10 ISP/2A integration baseline

This note records the OX03H10 ISP and 2A parameters inherited from the J722S
ADAS SDK debugging baseline. That baseline used the same OX03H10 sensor and
J722S VPAC ISP, but its ADAS camera-service control path is not present in the
BeagleY-AI Edge AI stack. Sensor parameters are therefore used as the reference;
the control path is adapted to V4L2 and `edgeai-gst-plugins`.

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
gains stay at the fixed values from the verified initialization sequence.

### Analog gain

HCG analog gain is written to:

- `0x3508`: integer and high fractional nibble
- `0x3509`: low fractional nibble in bits 7:4

The sensor uses a 4.4 encoding: 16 is 1x and 248 is 15.5x.

### Digital/inverse gain

The ADAS implementation uses the four register pairs at `0x5da0` through
`0x5da7` as an equal per-channel digital-gain path. The OX03H10 datasheet names
these registers manual AWB inverse gain. Preserve the verified ADAS behavior and
set all four pairs to the same converted value; do not reinterpret them as the
exposure-channel digital gain registers merely from the datasheet label. Q8 input
is converted to the register's Q10 form with `value = gain * 2`, then split as
`high = value >> 7` and `low = (value << 1) & 0xff`. Bit 0 of `0x5da8` enables
the manual inverse-gain path.

The exposure-channel digital gain registers in the datasheet (`0x350a/b/c` and
corresponding channel variants) are not used by this first AE port.

## Current-stack adaptation

`gsttiovxisp` now recognizes `SENSOR_OX03H10`, installs the ADAS exposure
program, and maps TI 2A output to the Linux controls:

- `V4L2_CID_EXPOSURE`: double-row exposure units
- `V4L2_CID_ANALOGUE_GAIN`: sensor 4.4 gain code
- `V4L2_CID_GAIN`: Q8 digital/inverse gain

Automatic mode must pass the OX03H10 subdevice to the ISP sink pad with
`sink_0::device=...`. `ox03h10-stream -m auto` auto-detects an `ox03h10`
`/dev/v4l-subdev*`; use `-s` or `SENSOR_SUBDEV` to override it. Fixed-parameter
mode continues to disable host AE/AWB and does not require the subdev path.

## Validation order

1. List controls on the OX03H10 subdev and verify the three ranges.
2. With streaming stopped or active, set exposure and both gains, then read back
   sensor registers `0x3501/02`, `0x3541/42`, `0x3508/09`, and `0x5da0..0x5da8`.
3. Keep AWB disabled and sweep exposure 2, 5, 10, and 15 ms.
4. Keep exposure fixed and sweep analog gain 1.2x, 4x, 8x, and 15.5x.
5. Enable AE only after fixed-step behavior is monotonic and stable.

The TI 2A wrapper receives `sensor_pre_wb_gain=1` for OX03H10. Its previous
gains are initialized from the sensor's HCG WB registers (converted from Q10 to
TI's Q9 convention: B=991, G=512, R=1083). The state remains the sensor-side
gain because this port continues to apply AWB results in VISS. A zero-divisor
fallback to unity is also present in the wrapper. Automatic AWB still needs
board validation with a neutral target before being considered complete.
