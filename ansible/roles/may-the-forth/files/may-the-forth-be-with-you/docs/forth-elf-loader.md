# Forth ELF Loader Vocabulary

The operational path has the shellcode VM drive ELF loading through Forth words. The harness acquires ELF files into byte buffers and exposes bounded OS callbacks. Forth performs inspection, mapping, relocation planning, protection, initial-stack construction, and transfer decisions through polymorphic execution.

This keeps C in a support role: supply bytes, invoke the VM, and observe behavior. The C dry loader remains useful as a reference implementation and telemetry generator, but it should not be treated as the main loader design.

## Harness Entry

```sh
build/c_harness --elf-forth build/hello_dynamic
python3 harness/py_harness.py --elf-forth build/hello_dynamic
```

If no script is supplied, `--elf-forth` uses the packed artifact generated
from `examples/elf64_dryload.fs`. The `forth_dev.bin` development blob retains
textual-source compilation.

## Raw Buffer Words

```text
ebase  ( -- ptr )
elen   ( -- len )
u8     ( off -- value )
u16    ( off -- value )
u32    ( off -- value )
u64    ( off -- value )
```

The `u*` words read little-endian values from the harness-provided ELF buffer. Reads are bounded by `elen`; an out-of-range access fails the VM run.

## Image Buffer Words

```text
i8@    ( image_off -- value )
i8!    ( value image_off -- )
i64@   ( image_off -- value )
i64!   ( value image_off -- )
ecopy  ( elf_src image_dst count -- )
streq  ( object_a offset_a object_b offset_b -- equal )
```

These operate on bounded object mappings registered with the VM. The loader uses `ecopy` to copy `PT_LOAD` file ranges and `i64!` to apply supported relocations.

## Load Plan And Execution

The loader builds compact records in bounded VM scratch cells, executes the selected operations through callbacks, and optionally transfers when `--forth-transfer` is present.

The plan summary includes:

```text
plan_done
map_record_count
protection_record_count
executable_protection_count
dependency_count
entrypoint
entry_target_kind      1 = program entry, 2 = interpreter entry
relocation_work_count
relative_writes
symbolic_resolutions_needed
bss_total
image_span
```

Each map/protect record contains:

```text
record_index
record_kind           1 = PT_LOAD map
vaddr
memsz
filesz
flags
image_offset
bss
final_permission_mask
```

The plan is deliberately numeric so it stays small and easy to compare across polymorphic runs. A reader can layer a decoder on top without changing the VM.

## Real Mapping

The C harness exposes the generic services used by the Forth-produced plan:

```sh
build/c_harness --elf-forth build/hello_dynamic --rounds 2 --real-forth-mappings
build/c_harness --elf-forth-buffer-demo --rounds 2 --real-forth-mappings
```

Forth requests each object's initial writable mapping, records bounded source/object ranges, copies each `PT_LOAD` directly into that object, applies supported writes, and requests final protections. In transfer mode, mappings stay alive and the harness services Forth's final transfer record. The harness emits:

```text
forth_service
forth_object_record
forth_plan_summary
```

Without `--forth-transfer`, the mode stops after mapping/protection and readiness reporting and unmaps the objects.

Static ET_EXEC, static PIE, and buffer-only PIE can transfer directly. Dynamic PIE transfers to the Forth-mapped interpreter; it deliberately leaves native-linker relocation state pristine and defers main RELRO so `_dl_start` can safely complete initialization.

`--elf-forth-buffer-demo` provides the same static path from a synthetic ELF64 byte buffer created in memory, which exercises the “ELF from buffer” case without reading an ELF payload path.

## Debugger Inspection Hold

Reviewers can keep the real Forth-plan mapping alive for local debugger inspection:

```sh
build/c_harness --elf-forth build/hello_static --rounds 2 \
  --real-forth-mappings --debug-hold
```

The harness emits `forth_debug_hold` with:

- process ID,
- anonymous mapping base and length,
- entry address computed from the Forth load plan,
- `ready_except_transfer`,
- `blocked_reason`,
- `transferred:false`.

`--debug-hold` waits indefinitely. `--debug-hold-seconds N` keeps the mapping resident for a bounded interval and is useful for scripted checks. The hold occurs after bytes are copied and final page protections are applied, but before `munmap`.

This mode remains an inspection aid and does not call the entry address.

## Dynamic Linking Status

The Forth loader maps interpreter/dependency objects and applies supported relative and symbolic relocations in non-transfer mode. Symbol-provider lookup uses SYSV/GNU hash records, 32-bit hash equality, and a bounded 128-byte name confirmation. It tracks `DT_VERSYM`, `DT_VERNEED`, and `DT_VERDEF`, but does not yet enforce version constraints. DT_RELR is decoded and applied.

Dynamic metadata and relocation records remain Forth data. The harness reports only generic callback activity and object ownership; it does not decode symbol names, relocation types, or binding actions.

Forth emits one acquisition for every bounded, unique `DT_NEEDED` name and uses successive object slots. The acquisition boundary deduplicates file identities globally, preventing cycles and repeated edges from expanding the bounded graph. Main-object RUNPATH/RPATH `$ORIGIN` expansion supports private siblings, including relative loader paths, and unresolved origin candidates fall back to the default system directory without consuming object slots. `streq` requires matching NUL-terminated symbol names within the 128-byte loader name bound after GNU-hash equality. Forth persists requester `DT_VERNEED`/`DT_VERNEEDNUM` and provider `DT_VERDEF`/`DT_VERDEFNUM` across discovery passes for version enforcement. Multiple search components and per-dependency origin state remain incomplete. Those are followed by version matching, TLS, IFUNC/IRELATIVE, constructors, and final direct entry.

## ELF Field Words

The VM supplies only bounded `u8`, `u16`, `u32`, and `u64` reads. The loader
declares ELF header and program-header offsets as Forth constants and builds
`e-*`, `ph-base`, `ph-u32`, `ph-u64`, and named field words from them. A field
layout can therefore be changed without modifying or rebuilding the VM.

## Current Script

`examples/elf64_dryload.fs` emits numeric fields in this order:

- ELF header: magic, class, data, type, machine, entry, phoff, phentsz, phnum.
- header validation predicate for magic/class/endianness/machine.
- For every program header from `0` to `e_phnum - 1`: index, type, flags, offset, vaddr, filesz, memsz, align.
- `PF_X`, `PF_W`, and `PF_R` masks for each program header.
- BSS size, segment end, and type predicates for `PT_LOAD`, `PT_INTERP`, and `PT_DYNAMIC`.
- Forth-side aggregate decisions: `PT_LOAD` count, `PT_INTERP` count, `PT_DYNAMIC` count, and total BSS across loadable segments.
- Forth-side image facts: lowest virtual address, highest loaded end, image span, copied load segment count, and sample bytes from the non-executable image buffer.
- Dynamic-section facts discovered in Forth: `DT_NEEDED` count plus RELA/REL/JMPREL, PLT relocation, string table, symbol table, hash table, GNU hash table, and version table pointers/sizes where present.
- Relocation facts discovered in Forth: RELA total, relative relocations, relative relocations applied to the image buffer, symbolic relocations, jump slots, unsupported relocations, JMPREL entry count, and bounded dry-link relocation records.
- Load-plan facts: map/protect/dependency/relocation/entry summary plus one map/protect record for each `PT_LOAD`.

Unlike `examples/elf64_inspect.fs`, this script computes field offsets in Forth source with `u*`, arithmetic, and `and`. That is the direction of travel: the VM provides generic primitives, while the ELF-specific layout lives in Forth.

The script now names ELF offsets, program-header field offsets, and permission masks with compile-time `constant` definitions. That keeps magic numbers in Forth source rather than in native opcodes or C parser logic.

It also defines inline Forth words:

```text
e-magic
e-class
e-data
e-machine
e-ok
ph-base
ph-addr
ph-u32
ph-u64
ph-perms
ph-x
ph-w
ph-r
ph-type
ph-load?
ph-interp?
ph-dynamic?
ph-filesz
ph-memsz
ph-vaddr
ph-bss
ph-end
plan-v!
plan-load
plan-finalize
img-off
rela-base
rela-off
rela-info
rela-addend
r-type
symbolic?
walk-rela
walk-jmprela
```

Those words are expanded by the VM compiler, so the runtime token stream remains flat while the source becomes more loader-like and much easier to evolve.

The script now uses the generic counted loop form:

```text
E-PHNUM u16 for
  i ph-type . cr
  ...
next
```

It also uses source-level conditionals for aggregate loader decisions:

```text
0 E-PHNUM u16 for
  i ph-load? if 1 + then
next . cr
```

That moves the program-header walk and basic segment classification into Forth source while keeping the VM primitive set small. The transformer now repairs `for`/`next` and `if`/`else`/`then` offsets after each transform round, so this branch-heavy loader vocabulary can execute from the transformed token stream.

The script also uses `m@`/`m!` scratch cells to retain loader state while walking headers, dynamic entries, image layout, and relocation tables. That keeps stateful loader logic in Forth source while the VM only supplies generic bounded memory cells and image-buffer access.
