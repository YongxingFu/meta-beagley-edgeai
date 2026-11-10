#!/usr/bin/env python3

import pathlib
import struct
import sys
import zlib


DCC_NAMES = (
    "dcc_2a_wdr_304.bin",
    "dcc_viss_wdr_304.bin",
)


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} WORKDIR DESTDIR", file=sys.stderr)
        return 2

    workdir = pathlib.Path(sys.argv[1])
    source_dir = workdir / "dcc/ox03h10/wdr"
    dest = pathlib.Path(sys.argv[2]) / "opt/imaging/ox03h10/wdr"
    dest.mkdir(parents=True, exist_ok=True)

    for name in DCC_NAMES:
        source = source_dir / name
        data = source.read_bytes()
        if len(data) < 4:
            print(f"{source} is too short to contain a file CRC", file=sys.stderr)
            return 1

        stored_crc = struct.unpack(">I", data[-4:])[0]
        calculated_crc = zlib.crc32(data[:-4]) & 0xFFFFFFFF
        if stored_crc != calculated_crc:
            print(
                f"{source} CRC mismatch: stored 0x{stored_crc:08x} "
                f"calculated 0x{calculated_crc:08x}",
                file=sys.stderr,
            )
            return 1

        # TI DCC does not define a file-level CRC trailer. Preserve the
        # supplied artifact and install only its valid DCC bytes for tiovxisp.
        (dest / f"{name}.orig").write_bytes(data)
        (dest / name).write_bytes(data[:-4])
        (dest / f"{name}.crc32").write_text(
            f"{calculated_crc:08x}\n", encoding="ascii"
        )

        for output in (dest / name, dest / f"{name}.orig", dest / f"{name}.crc32"):
            output.chmod(0o644)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
