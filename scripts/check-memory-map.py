#!/usr/bin/env python3
"""Validate an applied DTB against the memory map used to build the firmware."""
import argparse
from pathlib import Path
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dtb", help="DTB with the Edge AI overlay already applied")
    parser.add_argument("firmware_header", help="matching generated app_mem_map.h")
    args = parser.parse_args()

    def get(node, prop, kind="x", optional=False):
        result = subprocess.run(
            ["fdtget", "-t", kind, args.dtb, node, prop],
            capture_output=True, text=True,
        )
        if result.returncode:
            if optional:
                return None
            raise ValueError(f"Cannot read {node}/{prop}: {result.stderr.strip()}")
        return result.stdout.strip()

    def children(node):
        return subprocess.check_output(
            ["fdtget", "-l", args.dtb, node], text=True,
        ).split()

    def ranges(node):
        raw = get(node, "reg", optional=True)
        if raw is None:
            return []
        cells = [int(value, 16) for value in raw.split()]
        if len(cells) % 4:
            raise ValueError(f"Expected two address and two size cells at {node}")
        return [
            ((cells[i] << 32) | cells[i + 1], (cells[i + 2] << 32) | cells[i + 3])
            for i in range(0, len(cells), 4)
        ]

    if get("/", "#address-cells") != "2" or get("/", "#size-cells") != "2":
        raise ValueError("This checker expects the K3 two-cell memory format")
    ram = []
    for node in children("/"):
        path = "/" + node
        if get(path, "device_type", kind="s", optional=True) == "memory":
            ram.extend(ranges(path))
    if not ram:
        raise ValueError("No RAM banks found")

    shared = None
    checked = 0
    for node in children("/reserved-memory"):
        path = "/reserved-memory/" + node
        if get(path, "status", kind="s", optional=True) == "disabled":
            continue
        for base, size in ranges(path):
            if not size or not any(
                base >= start and base + size <= start + length
                for start, length in ram
            ):
                raise ValueError(f"{path}: [{base:#x}, {base + size:#x}) is outside RAM")
            checked += 1
        if node == "vision_apps_shared-memories":
            shared = ranges(path)
    if shared is None or len(shared) != 1:
        raise ValueError("Expected one active vision_apps_shared-memories region")

    header = Path(args.firmware_header).read_text()

    def macro(name):
        match = re.search(
            rf"^\s*#define\s+{name}\s+\(?\s*(0x[0-9a-fA-F]+|\d+)[uUlL]*\s*\)?\s*$",
            header, re.MULTILINE,
        )
        if not match:
            raise ValueError(f"Missing numeric macro {name}")
        return int(match.group(1), 0)

    expected = (macro("DDR_SHARED_MEM_PHYS_ADDR"), macro("DDR_SHARED_MEM_PHYS_SIZE"))
    if shared[0] != expected:
        raise ValueError(f"DT shared memory {shared[0]} differs from firmware {expected}")

    def symbol_range(symbol):
        path = get("/__symbols__", symbol, kind="s")
        values = ranges(path)
        if get(path, "status", kind="s", optional=True) == "disabled" or len(values) != 1:
            raise ValueError(f"Expected one active range for {symbol}")
        return values[0]

    for prefix, symbol in [
        ("DDR_MCU1_0", "vision_apps_mcu_r5fss0_core0"),
        ("DDR_MCU2_0", "vision_apps_main_r5fss0_core0"),
        ("DDR_C7x_1", "vision_apps_c71_0"),
        ("DDR_C7x_2", "vision_apps_c71_1"),
    ]:
        for suffix, region in [("IPC", "dma_memory_region"), ("DTS", "memory_region")]:
            expected_range = (macro(f"{prefix}_{suffix}_ADDR"), macro(f"{prefix}_{suffix}_SIZE"))
            actual_range = symbol_range(f"{symbol}_{region}")
            if actual_range != expected_range:
                raise ValueError(f"{prefix}_{suffix}: DT {actual_range} differs from firmware {expected_range}")

    ipc = symbol_range("vision_apps_rtos_ipc_memory_region")
    if ipc != (macro("IPC_VRING_MEM_ADDR"), macro("IPC_VRING_MEM_SIZE")):
        raise ValueError("IPC vring reservation differs from firmware")
    comm_base, comm_size = symbol_range("vision_apps_memory_region")
    for prefix in ["APP_LOG_MEM", "APP_FILEIO_MEM", "TIOVX_OBJ_DESC_MEM", "TIOVX_LOG_RT_MEM"]:
        base, size = macro(prefix + "_ADDR"), macro(prefix + "_SIZE")
        if base < comm_base or base + size > comm_base + comm_size:
            raise ValueError(f"{prefix} is outside the communication reservation")

    print(f"PASS: {checked} active reserved ranges fit RAM; firmware, IPC and shared memory agree")
    print(f"RAM: {sum(length for _, length in ram) // (1024**2)} MiB")
    print(f"AI shared memory: {expected[0]:#x}, {expected[1] // (1024**2)} MiB")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        raise SystemExit(f"FAIL: {exc}")
