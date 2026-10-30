#!/usr/bin/env python3
"""Pack a normalized .fthc compile artifact for the production VM decoder."""

import argparse
import pathlib
import struct

RAW_MAGIC = 0x31434D4854524F46
PACKED_MAGIC = 0x32504D4854524F46
RAW_HEADER = struct.Struct("<QIIIIII")
PACKED_HEADER = struct.Struct("<QIIII")
DICT_ENTRY_SIZE = 48
DICT_CONST = 1
DICT_CALLABLE = 3
OP_CALL = 82
OP_DROP = 3
OP_RET = 83
OP_NOP_ALT = 91
OP_FOR = 52
OP_NEXT = 54
OP_BRZ = 55
OP_BR = 56
MAX_ROUNDS = 4


def uint(value):
    result = bytearray()
    while value >= 0x80:
        result.append((value & 0x7F) | 0x80)
        value >>= 7
    result.append(value)
    return result


def token_list(data):
    if len(data) % 16:
        raise ValueError("unaligned token stream")
    return list(struct.iter_unpack("<QQ", data))


def compact_tokens(values, metric_offset):
    removed = set()
    for index, (op, immediate) in enumerate(values):
        if op == OP_CALL and (immediate & 0xFFFFFFFF) == metric_offset:
            if index == 0 or values[index - 1][0] != 1:
                raise ValueError("metric+ call is not paired with an address literal")
            removed.update((index - 1, index))
    before = [0]
    for index in range(len(values)):
        before.append(before[-1] + (index not in removed))
    result = []
    for index, (op, immediate) in enumerate(values):
        if index in removed:
            continue
        if op in (OP_FOR, OP_NEXT, OP_BRZ, OP_BR):
            signed = immediate if immediate < 1 << 63 else immediate - (1 << 64)
            target = index + 1 + signed
            if target < 0 or target > len(values) or target in removed:
                raise ValueError("removed metric token is a control-flow target")
            immediate = (before[target] - before[index + 1]) & ((1 << 64) - 1)
        result.append((op, immediate))
    return result


def tokens(values):
    result = bytearray()
    for op, immediate in values:
        if op > 255:
            raise ValueError(f"opcode {op} is not byte encodable")
        if op == OP_CALL and (immediate & 0xFFFFFFFF) >= 475136:
            raise ValueError("CALL target is not workspace-relative")
        result.append(op)
        result += uint(immediate)
    return result


def pack(raw, compact=False):
    magic, version, entries, dictionary_bytes, main_count, word_tokens, reserved = RAW_HEADER.unpack_from(raw)
    if magic != RAW_MAGIC or version != 1 or reserved:
        raise ValueError("unsupported raw compile artifact")
    cursor = RAW_HEADER.size
    dictionary_end = cursor + dictionary_bytes
    if dictionary_end + main_count * 16 != len(raw):
        raise ValueError("raw artifact length mismatch")
    bodies = []
    for _ in range(entries):
        entry = raw[cursor:cursor + DICT_ENTRY_SIZE]
        if len(entry) != DICT_ENTRY_SIZE:
            raise ValueError("truncated dictionary")
        kind, metadata, body_offset = struct.unpack_from("<QQQ", entry)
        name_length = struct.unpack_from("<Q", entry, 24)[0]
        name = entry[32:32 + name_length]
        cursor += DICT_ENTRY_SIZE
        if kind == DICT_CONST:
            continue
        if kind != DICT_CALLABLE:
            raise ValueError(f"dictionary kind {kind}")
        stored_count = metadata & 0xFFFF
        if stored_count <= MAX_ROUNDS:
            raise ValueError("callable body lacks fixed padding")
        count = stored_count - MAX_ROUNDS
        if body_offset != cursor - RAW_HEADER.size + 16896 + 49152:
            raise ValueError("non-canonical callable body offset")
        stored_body = raw[cursor:cursor + stored_count * 16]
        if len(stored_body) != stored_count * 16:
            raise ValueError("truncated callable body")
        split = (count - 1) * 16
        body = stored_body[:split] + stored_body[-16:]
        bodies.append((body_offset, count, name, token_list(body)))
        cursor += stored_count * 16
    if cursor != dictionary_end or sum(count for _, count, _, _ in bodies) != word_tokens:
        raise ValueError("dictionary topology mismatch")

    main = token_list(raw[dictionary_end:])
    if compact:
        metric = [offset for offset, _, name, _ in bodies if name == b"metric+"]
        if len(metric) != 1:
            raise ValueError("compact artifact requires exactly one metric+ word")
        metric_offset = metric[0]
        bodies = [(offset, compact_tokens(body, metric_offset))
                  for offset, _, name, body in bodies if name != b"metric+"]
        main = compact_tokens(main, metric_offset)
    else:
        bodies = [(offset, body) for offset, _, _, body in bodies]
    word_tokens = sum(len(body) for _, body in bodies)
    result = bytearray(PACKED_HEADER.pack(PACKED_MAGIC, 2, len(bodies), len(main), word_tokens))
    for offset, body in bodies:
        count = len(body)
        result += uint(offset)
        result += uint(count)
        result += tokens(body)
    result += tokens(main)
    return result


parser = argparse.ArgumentParser()
parser.add_argument("input", type=pathlib.Path)
parser.add_argument("output", type=pathlib.Path)
parser.add_argument("--compact", action="store_true")
args = parser.parse_args()
args.output.write_bytes(pack(args.input.read_bytes(), args.compact))
