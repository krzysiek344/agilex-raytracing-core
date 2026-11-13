#!/usr/bin/env python3
"""
BVH: 128-bit words, 2 words/node, Q16.16.
w0: leaf, prim/left/right, min_x|cx, min_y|cy
w1: min_z|cz, max_x|r, max_y, max_z
node i -> words 2*i, 2*i+1
"""

from pathlib import Path

OUT = Path(__file__).parent / "out"


def q16(x):
    return int(round(x * 65536)) & 0xFFFFFFFF


def pack_box(left, right, mn, mx):
    w0 = (left & 0xFFFF) << 16
    w0 |= (right & 0xFFFF) << 32
    w0 |= q16(mn[0]) << 48
    w0 |= q16(mn[1]) << 80
    w1 = q16(mn[2])
    w1 |= q16(mx[0]) << 32
    w1 |= q16(mx[1]) << 64
    w1 |= q16(mx[2]) << 96
    return w0, w1


def pack_sphere(prim_id, c, r):
    w0 = 1
    w0 |= (prim_id & 0x7FFF) << 1
    w0 |= q16(c[0]) << 48
    w0 |= q16(c[1]) << 80
    w1 = q16(c[2])
    w1 |= q16(r) << 32
    return w0, w1


def main():
    words = []
    words += pack_box(1, 1, (-1, -1, -1), (1, 1, 1))
    words += pack_sphere(0, (0, 0, 0), 1.0)

    OUT.mkdir(exist_ok=True)

    hex_lines = [f"{w:032X}" for w in words]
    (OUT / "scene_sphere.hex").write_text("\n".join(hex_lines) + "\n")

    mif = [
        f"DEPTH = {len(words)};",
        "WIDTH = 128;",
        "ADDRESS_RADIX = HEX;",
        "DATA_RADIX = HEX;",
        "CONTENT BEGIN",
    ]
    for i, h in enumerate(hex_lines):
        mif.append(f"  {i:X} : {h};")
    mif.append("END;")
    (OUT / "scene_sphere.mif").write_text("\n".join(mif) + "\n")

    for i, h in enumerate(hex_lines):
        print(i, h)


if __name__ == "__main__":
    main()