#!/usr/bin/env python3
import argparse
import ctypes
import mmap
import os
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from workspace_layout import (
    OUTPUT_SIZE,
    IMAGE_SIZE,
    DATA_BASE_OFF,
    FORTH_OBJECT_RECORD_BASE,
    FORTH_OBJECT_RECORD_SIZE,
    FORTH_OBJECT_RECORD_MAX,
    FORTH_SOURCE_SIZE_MAX,
    FORTH_OBJECT_MAP_MAX,
    WORKSPACE_META_STRUCT,
    WORKSPACE_SIZE,
    WS_ELF_BASE_OFF,
    WS_ELF_LEN_OFF,
    WS_FLAGS_OFF,
    WS_FLAG_COMPILE_ONLY,
    WS_FLAG_CALLABLE,
    WS_FLAG_SYSCALL_SERVICES,
    WS_MAGIC_VALUE,
    WS_ROUNDS_OFF,
    WS_SERVICE_MAP_OFF,
    WS_SERVICE_UNMAP_OFF,
    WS_SERVICE_PROTECT_OFF,
    WS_SERVICE_READ_FILE_OFF,
    WS_SERVICE_CLOSE_OFF,
    WS_SERVICE_CONTEXT_OFF,
)



def load_blob(path: str) -> bytes:
    with open(path, "rb") as f:
        return f.read()


def executable_mapping(blob: bytes) -> mmap.mmap:
    mm = mmap.mmap(
        -1,
        len(blob),
        flags=mmap.MAP_PRIVATE | mmap.MAP_ANONYMOUS,
        prot=mmap.PROT_READ | mmap.PROT_WRITE | mmap.PROT_EXEC,
    )
    mm.write(blob)
    return mm


class StandaloneBootstrap(ctypes.Structure):
    _fields_ = [
        ("magic", ctypes.c_uint64),
        ("version", ctypes.c_uint64),
        ("path", ctypes.c_void_p),
        ("path_len", ctypes.c_uint64),
        ("flags", ctypes.c_uint64),
        ("argc", ctypes.c_uint64),
        ("argv", ctypes.c_void_p),
        ("envp", ctypes.c_void_p),
        ("bundle_length", ctypes.c_uint64),
    ]


def run_embedded(bundle_path: str, target_args: list[str], raw: bool) -> int:
    blob = load_blob(bundle_path)
    mapping = mmap.mmap(-1, len(blob), flags=mmap.MAP_PRIVATE | mmap.MAP_ANONYMOUS,
                        prot=mmap.PROT_READ | mmap.PROT_WRITE)
    mapping.write(blob)
    address = ctypes.addressof(ctypes.c_char.from_buffer(mapping))
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.mprotect(ctypes.c_void_p(address), len(blob), mmap.PROT_READ | mmap.PROT_EXEC):
        raise OSError(ctypes.get_errno(), "mprotect bundle")
    fn = ctypes.CFUNCTYPE(None, ctypes.c_void_p)(address)
    if raw:
        fn(None)
        return 111
    strings = [ctypes.create_string_buffer(bundle_path.encode())]
    strings.extend(ctypes.create_string_buffer(arg.encode()) for arg in target_args)
    argv = (ctypes.c_void_p * (len(strings) + 1))()
    for index, string in enumerate(strings):
        argv[index] = ctypes.addressof(string)
    environment = [ctypes.create_string_buffer(f"{key}={value}".encode())
                   for key, value in os.environ.items()]
    envp = (ctypes.c_void_p * (len(environment) + 1))()
    for index, string in enumerate(environment):
        envp[index] = ctypes.addressof(string)
    boot = StandaloneBootstrap(0x31544F4F42485446, 2, argv[0],
                               len(bundle_path.encode()), 0, len(strings),
                               ctypes.addressof(argv), ctypes.addressof(envp), len(blob))
    fn(ctypes.addressof(boot))
    return 111


def run(
    blob_path: str,
    source: bytes,
    seed: int,
    rounds: int,
    elf_bytes: bytes | None = None,
    compile_only: bool = False,
    callable_words: bool = False,
    syscall_services: bool = False,
) -> tuple[int, bytes, tuple[int, ...]]:
    blob = load_blob(blob_path)
    mapping = executable_mapping(blob)
    addr = ctypes.addressof(ctypes.c_char.from_buffer(mapping))

    input_buf = ctypes.create_string_buffer(source)
    output_buf = ctypes.create_string_buffer(OUTPUT_SIZE)
    workspace = ctypes.create_string_buffer(WORKSPACE_SIZE)
    libc = ctypes.CDLL(None, use_errno=True)
    libc.mmap.restype = ctypes.c_void_p
    service_type = ctypes.CFUNCTYPE(ctypes.c_uint64, ctypes.c_void_p, ctypes.c_uint64,
                                    ctypes.c_uint64, ctypes.c_uint64, ctypes.c_uint64)
    object_maps: list[tuple[int, int]] = []
    source_buffers: list[ctypes.Array | None] = [None] * FORTH_OBJECT_RECORD_MAX
    workspace_address = ctypes.addressof(workspace)

    @service_type
    def service_map(_context, desired, length, prot, flags):
        if not length or length > FORTH_OBJECT_MAP_MAX or prot & ~3 or flags & ~3:
            return 0
        mmap_flags = mmap.MAP_PRIVATE | mmap.MAP_ANONYMOUS
        if flags & 2:
            mmap_flags |= 0x100000  # MAP_FIXED_NOREPLACE
        result = libc.mmap(ctypes.c_void_p(desired), length, prot, mmap_flags, -1, 0)
        address = ctypes.cast(result, ctypes.c_void_p).value or 0
        if address == ctypes.c_void_p(-1).value:
            return 0
        object_maps.append((address, length))
        return address

    def object_range(address: int, length: int) -> bool:
        return (address >= workspace_address and address + length <= workspace_address + WORKSPACE_SIZE) or any(
            address >= base and address + length <= base + size for base, size in object_maps)

    @service_type
    def service_unmap(_context, address, length, _arg2, _arg3):
        if (address, length) not in object_maps:
            return ctypes.c_uint64(-22).value
        result = libc.munmap(ctypes.c_void_p(address), ctypes.c_size_t(length))
        if result == 0:
            object_maps.remove((address, length))
        return result

    @service_type
    def service_protect(_context, address, length, prot, _arg3):
        if not object_range(address, length) or prot & ~7:
            return ctypes.c_uint64(-22).value
        return libc.mprotect(ctypes.c_void_p(address), ctypes.c_size_t(length), prot)

    @service_type
    def service_read(_context, path_address, path_length, source_slot, capacity):
        if (not path_length or path_length >= 4096 or source_slot >= FORTH_OBJECT_RECORD_MAX or
                not capacity or capacity > FORTH_SOURCE_SIZE_MAX or source_buffers[source_slot] is not None or
                not object_range(path_address, path_length)):
            return ctypes.c_uint64(-22).value
        try:
            path = ctypes.string_at(path_address, path_length).decode()
            handle = os.open(path, os.O_RDONLY)
            data = os.read(handle, capacity + 1)
        except OSError as error:
            return ctypes.c_uint64(-error.errno).value
        if len(data) > capacity:
            os.close(handle)
            return ctypes.c_uint64(-27).value
        source = ctypes.create_string_buffer(data)
        source_buffers[source_slot] = source
        record = DATA_BASE_OFF + (FORTH_OBJECT_RECORD_BASE + source_slot * FORTH_OBJECT_RECORD_SIZE) * 8
        struct.pack_into("<QQQ", workspace, record + 8, 2, ctypes.addressof(source), len(data))
        return handle

    @service_type
    def service_close(_context, handle, _arg1, _arg2, _arg3):
        try:
            os.close(handle)
            return 0
        except OSError as error:
            return ctypes.c_uint64(-error.errno).value

    for offset, callback in ((WS_SERVICE_MAP_OFF, service_map),
                             (WS_SERVICE_UNMAP_OFF, service_unmap),
                             (WS_SERVICE_PROTECT_OFF, service_protect),
                             (WS_SERVICE_READ_FILE_OFF, service_read),
                             (WS_SERVICE_CLOSE_OFF, service_close)):
        struct.pack_into("<Q", workspace, offset, ctypes.cast(callback, ctypes.c_void_p).value or 0)
    struct.pack_into("<Q", workspace, WS_SERVICE_CONTEXT_OFF, 0)
    struct.pack_into("<QQ", workspace, 0, WS_MAGIC_VALUE, seed)
    struct.pack_into("<Q", workspace, WS_ROUNDS_OFF, rounds)
    if compile_only:
        struct.pack_into("<Q", workspace, WS_FLAGS_OFF, WS_FLAG_COMPILE_ONLY)
    if callable_words:
        current_flags = struct.unpack_from("<Q", workspace, WS_FLAGS_OFF)[0]
        struct.pack_into("<Q", workspace, WS_FLAGS_OFF, current_flags | WS_FLAG_CALLABLE)
    if syscall_services:
        current_flags = struct.unpack_from("<Q", workspace, WS_FLAGS_OFF)[0]
        struct.pack_into("<Q", workspace, WS_FLAGS_OFF, current_flags | WS_FLAG_SYSCALL_SERVICES)
    elf_buf = ctypes.create_string_buffer(elf_bytes) if elf_bytes is not None else None
    if elf_buf is not None:
        struct.pack_into(
            "<QQ",
            workspace,
            WS_ELF_BASE_OFF,
            ctypes.cast(elf_buf, ctypes.c_void_p).value or 0,
            len(elf_bytes),
        )
        record = DATA_BASE_OFF + FORTH_OBJECT_RECORD_BASE * 8
        struct.pack_into("<QQQ", workspace, record + 8, 1,
                         ctypes.cast(elf_buf, ctypes.c_void_p).value or 0, len(elf_bytes))

    fn_type = ctypes.CFUNCTYPE(
        ctypes.c_int64,
        ctypes.c_void_p,
        ctypes.c_uint64,
        ctypes.c_void_p,
        ctypes.c_uint64,
        ctypes.c_void_p,
        ctypes.c_uint64,
    )
    fn = fn_type(addr)
    rc = fn(
        ctypes.cast(input_buf, ctypes.c_void_p),
        len(source),
        ctypes.cast(output_buf, ctypes.c_void_p),
        OUTPUT_SIZE,
        ctypes.cast(workspace, ctypes.c_void_p),
        WORKSPACE_SIZE,
    )
    meta = struct.unpack_from(WORKSPACE_META_STRUCT, workspace, 8)
    out = output_buf.raw[: max(rc, 0)]
    for address, length in object_maps:
        libc.munmap(ctypes.c_void_p(address), ctypes.c_size_t(length))
    mapping.close()
    return rc, out, meta


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--blob")
    parser.add_argument("--script", default="examples/math.fs")
    parser.add_argument("--input")
    parser.add_argument("--elf-forth")
    parser.add_argument("--embedded")
    parser.add_argument("--embedded-raw", action="store_true")
    parser.add_argument("--seed", type=lambda s: int(s, 0), default=1)
    parser.add_argument("--rounds", type=lambda s: int(s, 0), default=1)
    parser.add_argument("--compile-only", action="store_true")
    parser.add_argument("--callable-words", action="store_true")
    parser.add_argument("--syscall-services", action="store_true")
    parser.add_argument("target_args", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    if args.embedded:
        return run_embedded(args.embedded, args.target_args, args.embedded_raw)
    if args.embedded_raw:
        parser.error("--embedded-raw requires --embedded")

    if args.elf_forth and args.input is None and args.script == "examples/math.fs":
        args.script = "build/elf64_dryload.instrumented.fthp"

    if args.blob is None:
        args.blob = "build/forth.bin" if args.script.endswith(".fthp") else "build/forth_dev.bin"

    if args.input is not None:
        source = args.input.encode()
    else:
        with open(args.script, "rb") as f:
            source = f.read()
    elf_bytes = None
    if args.elf_forth:
        with open(args.elf_forth, "rb") as f:
            elf_bytes = f.read()

    rc, out, meta = run(args.blob, source, args.seed, args.rounds, elf_bytes, args.compile_only, args.callable_words, args.syscall_services)
    sys.stdout.write(f"forth_output={out.decode(errors='replace')}")
    if not out.endswith(b"\n"):
        sys.stdout.write("\n")
    (
        seed,
        flags,
        original,
        transformed,
        transforms,
        status,
        _outbase,
        _orig_base,
        _xform_base,
        _trace_base,
        trace_count,
        max_depth,
        final_depth,
        error_at,
        validate_status,
        _scratch_base,
        rounds,
        rounds_done,
        _previous_base,
        _previous_tokens,
        _elf_base,
        _elf_len,
        _control_depth,
    ) = meta
    sys.stdout.write(
        "forth_meta="
        f'{{"rc":{rc},"seed":{seed},"flags":{flags},'
        f'"original_tokens":{original},"transformed_tokens":{transformed},'
        f'"transforms":{transforms},"status":{status},'
        f'"max_depth":{max_depth},"final_depth":{final_depth},'
        f'"trace_count":{trace_count},"validate_status":{validate_status},'
        f'"error_at":{error_at},"rounds":{rounds},'
        f'"rounds_done":{rounds_done}}}\n'
    )
    return 0 if rc >= 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
