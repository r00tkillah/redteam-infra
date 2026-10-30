# ELF Dry Loader

There are now two ELF paths:

- the operational Forth ELF loader, where the shellcode VM reads ELF buffers, maps loadable bytes, drives loader policy, and can transfer control;
- the C reference dry loader, which still simulates deeper loader mechanics without transferring control to mapped code.

The Forth path is the primary implementation. The C path remains an oracle and telemetry stimulus.

See [Forth ELF Loader Vocabulary](forth-elf-loader.md) for the VM-side words. That path now covers header validation, program-header walking, `PT_LOAD` image copies, load-plan construction, dynamic-table discovery, RELA/JMPREL counting from Forth source, and optional real anonymous mappings driven by the Forth plan.

## C Reference Loader

It accepts two source modes:

- `--elf path`: load ELF bytes from disk.
- `--elf-buffer-demo`: build a synthetic ELF64 image in memory and dry-load that buffer.

Both C reference modes call the same buffer-oriented parser.

## Validation

The dry loader validates:

- ELF magic,
- 64-bit class,
- little-endian encoding,
- x86_64 machine type,
- program header entry size and bounds,
- `PT_LOAD` segment file bounds,
- segment memory/file size consistency,
- segment virtual address overflow,
- alignment constraints.

## Image Layout

The dry loader allocates one anonymous RW image buffer, copies all `PT_LOAD` file bytes into their relative offsets, and leaves BSS zeroed.

It reports this as:

```text
elf_image={"mapped":"anonymous_nonexec_rw", ...}
```

By default the image remains non-executable. With `--elf-exec-protections`, the dry loader applies final segment page protections with `mprotect`, including RX on executable load segments. It still never jumps to the image.

## Dynamic Section And Relocations

For dynamic ELFs, the dry loader parses `PT_DYNAMIC` and reports:

- `DT_NEEDED` count,
- RELA/REL table presence and sizes,
- PLT relocation presence and size,
- relocation requirement.

It walks RELA, REL, and JMPREL tables. It applies safe `R_X86_64_RELATIVE` relocations inside the anonymous image and reports symbolic resolver work without resolving it.

Useful records:

- `elf_dynamic`
- `elf_relocations`

## Interpreter Dry Runs

Dynamic ELFs often contain `PT_INTERP`, usually pointing at the system dynamic linker. `--ld-dry-runs N` repeatedly opens, reads, and dry-loads that interpreter path. The value is clamped to 4.

This creates loader-like telemetry such as repeated dynamic-linker file opens, mapping, relocation walking, and optional executable protections without executing the dynamic linker.

## Initial Stack And Entry Transfer

The dry loader reports the initial stack/auxv values it would prepare:

```text
elf_initial_stack={...}
```

It also reports the target that would receive control:

```text
elf_entry_transfer={"target":"interpreter","transferred":false}
```

`transferred` is always `false`.

## Demo ELFs

`build/hello_dynamic` is a benign dynamically linked ELF.

`build/hello_static` is a benign statically linked syscall-only ELF.

They allow side-by-side inspection of dynamic and static loader paths:

```sh
build/c_harness --script examples/math.fs --seed 7 --elf build/hello_dynamic
build/c_harness --script examples/math.fs --seed 7 --elf build/hello_static
```
