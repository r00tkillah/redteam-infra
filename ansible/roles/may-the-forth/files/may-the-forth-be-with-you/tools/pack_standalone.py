#!/usr/bin/env python3
import argparse
import struct
from pathlib import Path

BUNDLE_MAGIC = 0x314C444E42485446
BUNDLE_VERSION = 1
MANIFEST = struct.Struct("<10Q")
SOURCE_SIZE_MAX = 16_777_216
SIGNAL_PREFIX = (b"\xf3\x0f\x1e\xfa\x31\xff\xe9\x09\x00\x00\x00"
                 b"\xb8\x0f\x00\x00\x00\x0f\x05\x0f\x0b")


def validate_static_elf(data: bytes) -> None:
    if len(data) < 64 or data[:4] != b"\x7fELF":
        raise ValueError("payload is not an ELF")
    if data[4:6] != b"\x02\x01" or struct.unpack_from("<H", data, 18)[0] != 62:
        raise ValueError("payload must be little-endian ELF64 for x86-64")
    elf_type = struct.unpack_from("<H", data, 16)[0]
    phoff = struct.unpack_from("<Q", data, 32)[0]
    ehsize, phentsize, phnum = struct.unpack_from("<HHH", data, 52)
    if elf_type not in (2, 3):
        raise ValueError("payload must be ET_EXEC or ET_DYN")
    if ehsize != 64 or phentsize != 56 or not phnum:
        raise ValueError("unsupported ELF/program-header layout")
    if phoff > len(data) or phnum > (len(data) - phoff) // phentsize:
        raise ValueError("program headers exceed payload")
    load_count = 0
    for index in range(phnum):
        p_type, p_flags = struct.unpack_from("<II", data, phoff + index * phentsize)
        if p_type == 3:
            raise ValueError("PT_INTERP is outside the embedded-static phase")
        if p_type == 1:
            load_count += 1
            if p_flags & 3 == 3:
                raise ValueError("writable-executable PT_LOAD is rejected")
    if not load_count:
        raise ValueError("payload has no PT_LOAD")


def pack(template_path: Path, payload_path: Path, output_path: Path,
         signal_entry: bool = False) -> None:
    template = bytearray(template_path.read_bytes())
    payload = payload_path.read_bytes()
    if template.startswith(SIGNAL_PREFIX) or payload.startswith(SIGNAL_PREFIX):
        raise ValueError("input already has a signal-entry prefix")
    if not payload or len(payload) > SOURCE_SIZE_MAX:
        raise ValueError("payload length is outside the accepted range")
    validate_static_elf(payload)
    marker = struct.pack("<QQ", BUNDLE_MAGIC, BUNDLE_VERSION)
    manifest_offset = template.find(marker)
    if manifest_offset < 0 or template.find(marker, manifest_offset + 1) >= 0:
        raise ValueError("loader template has no unique bundle manifest")
    if manifest_offset + MANIFEST.size != len(template):
        raise ValueError("bundle manifest must terminate the loader template")
    payload_offset = len(template)
    total_length = payload_offset + len(payload)
    MANIFEST.pack_into(template, manifest_offset, BUNDLE_MAGIC, BUNDLE_VERSION,
                       total_length, payload_offset, len(payload), 1, 1, 0, 0, 0)
    bundle = template + payload
    output_path.write_bytes((SIGNAL_PREFIX if signal_entry else b"") + bundle)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("template", type=Path)
    parser.add_argument("payload", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--signal-entry", action="store_true")
    args = parser.parse_args()
    try:
        pack(args.template, args.payload, args.output, args.signal_entry)
    except (OSError, ValueError, struct.error) as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
