# Polymorphic Forth Shellcode ELF Loader

This repository produces Linux x86_64 shellcode containing a static ELF and a
polymorphic Forth loader. A small Python, Ruby, Perl, or C harness allocates
executable memory, copies in the shellcode, and jumps to its first byte.
The loader embedded in the shellcode discovers the packaged ELF, maps its segments,
applies relocations and final protections, constructs the Linux entry stack, and
transfers control to the ELF's real entry point. The shellcode runner does not
parse or load the ELF.

The loader is implemented as Forth running inside a position-independent
shellcode VM. The VM compiles Forth to tokens, applies seeded polymorphic
transformations, validates the transformed stream, and executes it. That means
the ELF-loader program—not merely a decoder or section inspector—is subject to
polymorphic execution.

Embedded bundles currently support interpreter-free static and static-PIE
ELFs. The pathname-backed C harness additionally demonstrates static ET_EXEC,
randomized static PIE, buffer-only PIE, and interpreter-backed dynamic PIE
transfer. Inspection, dry-loader, detection, and BCC tooling elsewhere in the
repository are supporting regression and behavior-analysis utilities, not the
main payload path.

## How to play

Replay the short terminal demo with `asciinema play docs/demo.cast`, or run the
same commands yourself below.

Build, package the included static PIE, and execute the resulting shellcode:

```sh
make build
python3 tools/pack_standalone.py \
  build/standalone_loader.template.bin build/hello_static_pie build/demo.bundle
python3 harness/py_harness.py --embedded build/demo.bundle --embedded-raw
```

Replace `build/hello_static_pie` with your own interpreter-free Linux x86_64
static ELF. `build/demo.bundle` is the finished flat shellcode artifact; pass it
to any compatible shellcode runner. The included C runner works too:

```sh
build/standalone_launcher --embedded-raw build/demo.bundle
```

Core Perl can run the same loader without CPAN modules. Package the bundle with
the small signal-entry wrapper, then enter it through `rt_sigaction`:

```sh
python3 tools/pack_standalone.py --signal-entry \
  build/standalone_loader.template.bin build/hello_static_pie build/demo.signal.bundle
perl harness/perl_harness.pl --embedded-signal build/demo.signal.bundle
```

To watch different polymorphic token streams produce the same result:

```sh
python3 tools/run_matrix.py --harness build/c_harness \
  --script examples/math.fs --seeds 1,2,3 --rounds 2
```

`demo.bundle` is not an ELF. It is flat shellcode with the ELF packaged inside
it, and `--embedded-raw` gives its entry point no ELF pointer, pathname, file
descriptor, or loader callback. Execution succeeds because the shellcode-hosted
loader does the ELF loading and then runs the packaged program.

Maintainers can check every command in this section with `make demo-test`.

## Current Status

The core VM and harness workflow are working end to end:

- The VM is flat x86_64 shellcode. C/Python support callable and transfer
  workflows; Ruby calls raw embedded bundles through `Fiddle`; core Perl enters
  an IBT-compatible wrapper through `rt_sigaction`.
- Forth source is compiled to tokens, processed through seeded polymorphic transformations, validated, and executed as the transformed stream.
- The Forth vocabulary is large enough to express stack/math logic, branches, counted loops, scratch-memory state, bounded ELF-buffer reads, and bounded image-buffer copies/writes.
- `examples/elf64_dryload.fs` implements the operational Forth-side ELF loader: header checks, program-header walking, anonymous `PT_LOAD` mappings, dependency and relocation records, GNU-hash symbol lookup, load-plan construction, protection changes, initial-stack construction, and entry transfer.
- Static ET_EXEC, randomized static PIE, and buffer-only PIE inputs transfer directly to their entry points with `--forth-transfer`.
- Interpreter-backed dynamic PIE inputs transfer through the Forth-mapped interpreter. The native interpreter currently completes dependency loading, remaining relocations, initialization, and final control transfer.
- Detection examples observe behavior-level signals such as executable anonymous mappings, RW-to-RX transitions, file I/O near mapping activity, dynamic-linker dry-runs, and process execution near executable anonymous memory.

## What This Repo Contains

- `src/forth_vm.asm`: position-independent NASM Forth VM shellcode.
- `harness/c_harness.c`: primary shellcode harness, payload telemetry scenarios, and C reference ELF dry loader.
- `harness/py_harness.py`: Python shellcode harness for parity checks.
- `harness/ruby_harness.rb`: standard-library Fiddle embedded-bundle runner.
- `harness/perl_harness.pl`: CPAN-free signal-entry embedded-bundle runner.
- `tools/pack_standalone.py`: generic static and signal-entry bundle packer.
- `tools/probe_bcc.py`: BCC kprobe/kretprobe collector that emits JSONL.
- `detections/rules.py`: behavior correlation rules over JSONL probe events.
- `examples/`: Forth scripts, benign payload fixture, benign demo ELFs, and benign probe control source.
- `include/` and `tools/workspace_layout.py`: shared workspace/opcode metadata.
- `docs/`: deeper explainers for the VM, polymorphic execution, ELF loader simulation, and detection workflow.

## Quick Start

```sh
make build
make test
make probe-test
```

Build outputs are written under `build/`:

- `build/forth.bin`: flat Forth VM shellcode blob.
- `build/standalone_loader.template.bin`: source-free embedded-loader template.
- `build/go_static.bundle`: loader and static Go target packaged as one blob.
- `build/go_static.signal.bundle`: the same Go bundle with a 20-byte Perl
  signal-entry wrapper, generated by `make ruby-perl-runner-test`.
- `build/c_harness`: primary C harness.
- `build/hello_dynamic`: benign dynamically linked demo ELF.
- `build/hello_static`: benign statically linked syscall-only demo ELF.
- `build/hello_static_pie`: single-object position-independent static demo ELF.
- `build/benign_control`: benign live-probe baseline.

## Run The VM

```sh
build/c_harness --input '2 3 + . cr' --seed 1
python3 harness/py_harness.py --input '2 3 + . cr' --seed 1
```

Run a Forth script with multiple polymorphic execution rounds:

```sh
build/c_harness --script examples/math.fs --seed 7 --rounds 2 --dump-tokens
python3 tools/run_matrix.py --harness build/c_harness --script examples/math.fs --seeds 1,2,3 --rounds 2
```

Supported Forth words:

```text
: name ... ; constant
dup drop swap over + - * = < > . emit cr negate 0= 1+ 1- invert 2*
and or xor lshift rshift u< u> min max
m@ m! u/ i8@ i8! i64@ i64! ecopy ocall streq cpuid
for i next if else then
ebase elen u8 u16 u32 u64
```

The VM reports metadata such as original token count, transformed token count, transform count, trace count, requested/completed rounds, validation status, max stack depth, and final stack depth.

## Run The Forth ELF Inspector

The Forth-first loader path passes ELF buffers into the VM workspace. The harness supplies bytes and bounded host services; polymorphically executed Forth performs ELF inspection, mapping, relocation planning, protection changes, stack construction, and transfer decisions.

```sh
build/c_harness --elf-forth build/hello_dynamic
python3 harness/py_harness.py --elf-forth build/hello_dynamic
```

By default, `--elf-forth` runs the packed build artifact generated from
`examples/elf64_dryload.fs`. Use the development blob and an explicit `--script`
to compile textual Forth at runtime. ELF offsets, indexes, permission masks,
relocation constants, plan fields, and field accessors remain defined in Forth.

The standalone and embedded operational artifact uses reporting-free
implementations of `metric+`. Harness `--elf-forth` runs the instrumented
artifact by default so behavior research retains the GNU-chain, protection,
native-call, and constructor counters. Both artifacts come from the same Forth
core and choose the same load plan.

Forth can allocate and populate the main object through the generic callback ABI:

```sh
build/c_harness --elf-forth build/hello_dynamic --rounds 2 --real-forth-mappings
build/c_harness --elf-forth build/hello_static --rounds 2 --real-forth-mappings
build/c_harness --elf-forth-buffer-demo --rounds 2 --real-forth-mappings
```

Forth selects the final mapping address, calls the generic `map` service, copies bounded `PT_LOAD` ranges into the object, and applies supported relative writes there. The harness contains no active `dlopen`, `dlsym`, or harness-side Forth image binder.

Transfer to a linked static entry point is available after Forth finalizes its
segment permissions:

```sh
build/c_harness --elf-forth build/hello_static --rounds 2 --forth-transfer
build/c_harness --elf-forth build/hello_static_pie --rounds 2 --forth-transfer
```

Package an interpreter-free static ELF into a single byte-zero-entry blob:

```sh
python3 tools/pack_standalone.py \
  build/standalone_loader.template.bin target.elf output.bundle
build/standalone_launcher --embedded output.bundle [target-args...]
python3 harness/py_harness.py --embedded output.bundle [target-args...]
```

The runner maps the complete bundle and supplies optional argument and
environment data only. It does not pass an ELF pointer, pathname, callback, or
file descriptor. `--embedded-raw` supplies no bootstrap at all and uses the
embedded `argv[0]` with an empty environment. Embedded static mode rejects
`PT_INTERP`; use the pathname-backed standalone mode for dynamic objects.

Ruby can enter the ordinary raw bundle through standard-library `Fiddle`. A
core-Perl variant uses an IBT-compatible signal trampoline and `rt_sigaction`,
without CPAN modules:

```sh
ruby harness/ruby_harness.rb --embedded-raw build/go_static.bundle
python3 tools/pack_standalone.py --signal-entry \
  build/standalone_loader.template.bin target.elf output.signal.bundle
perl harness/perl_harness.pl --embedded-signal output.signal.bundle
```

Dynamic entry transfer uses the mapped interpreter selected by Forth. In this
mode Forth leaves interpreter/dependency relocation state pristine and defers
main-object RELRO so `_dl_start` can finish native initialization before the
program receives control:

```sh
build/c_harness --elf-forth build/hello_dynamic --rounds 2 --forth-transfer
```

Without `--forth-transfer`, the command remains an inspection/regression mode and returns after reporting the Forth plan.

## Generate Benign Payload Telemetry

These scenarios run after VM execution and are intentionally outside the shellcode VM. They produce useful local telemetry without adding payload execution features to the VM.

```sh
build/c_harness --script examples/math.fs --seed 3 --payload print
build/c_harness --script examples/math.fs --seed 3 --payload cat-fixture
build/c_harness --script examples/math.fs --seed 3 --payload spawn-id
build/c_harness --script examples/math.fs --seed 3 --payload all
```

`spawn-id` executes fixed argv for `/usr/bin/id`; it does not invoke a shell and does not accept a command string.

## Exercise The C Reference ELF Dry Loader

The C dry loader remains as a reference implementation and telemetry stimulus while the Forth loader vocabulary grows. Inspect a disk-backed ELF:

```sh
build/c_harness --script examples/math.fs --seed 7 --rounds 2 --elf build/hello_dynamic
build/c_harness --script examples/math.fs --seed 7 --rounds 2 --elf build/hello_static
```

Inspect an ELF-like image that is generated in memory rather than read from an ELF path:

```sh
build/c_harness --script examples/math.fs --seed 7 --rounds 2 --elf-buffer-demo
```

Generate richer loader-behavior telemetry without transferring control:

```sh
build/c_harness --script examples/math.fs --seed 7 --rounds 2 \
  --elf build/hello_dynamic \
  --elf-exec-protections \
  --ld-dry-runs 2
```

The C reference dry loader reports:

- `elf_source`: disk, memory buffer, or dynamic-linker dry-run source.
- `elf_segment`: segment sizes, BSS, flags, permissions, and alignment.
- `elf_image`: anonymous image layout used for the dry run.
- `elf_dynamic`: dynamic section and relocation table indicators.
- `elf_relocations`: relocation walk results and resolver requirements.
- `elf_initial_stack`: simulated initial stack/auxv setup.
- `elf_entry_transfer`: target that would receive control, always with `transferred:false`.
- `elf_report`: final summary with `execution:"not_transferred"`.

## Capture And Correlate Telemetry

Synthetic correlation tests:

```sh
make probe-test
```

Live BCC capture usually requires root:

```sh
make probe-live
```

That writes:

- `build/probe_events.jsonl`
- `build/probe_findings.jsonl`

Run a benign live control that should not trigger correlated detections:

```sh
make probe-control
```

Manual live capture:

```sh
sudo python3 tools/probe_bcc.py \
  --binary build/c_harness \
  --output build/probe_events.jsonl \
  -- build/c_harness --script examples/math.fs --rounds 2 --payload all \
     --elf build/hello_dynamic --elf-exec-protections --ld-dry-runs 2

python3 detections/rules.py build/probe_events.jsonl
```

By default, the probe collector filters to the launched process tree. Use `--all-pids` for system-wide capture. Harness symbol uprobes are available with `--lab-markers`, but detection rules intentionally ignore those markers.

## Detection Signals

The current rules correlate behavior such as:

- anonymous RW memory followed by RX protection,
- anonymous executable memory plus file I/O,
- executable anonymous memory lifecycle including `munmap`,
- repeated dynamic-linker opens near executable anonymous memory,
- process exec near executable anonymous memory.

The rules operate on behavior-level probe events, not on lab-only markers or printed harness metadata.

## Inspect

```sh
make inspect
```

This prints shellcode size, relocation status, section layout, and disassembly. The shellcode object is expected to have no relocations.

## Documentation

- [Architecture](docs/architecture.md)
- [Forth VM Shellcode ABI](docs/forth-vm.md)
- [Forth ELF Loader Vocabulary](docs/forth-elf-loader.md)
- [Polymorphic Execution](docs/polymorphism.md)
- [ELF Dry Loader](docs/elf-dry-loader.md)
- [Detection Workflow](docs/detection-workflow.md)

## Clear Next Steps

The remaining work makes the dynamic path independent of the native
interpreter's dependency loader while keeping the harness in a support role:

1. Recursively acquire and map dependency objects while deduplicating the graph and respecting RUNPATH/RPATH and `$ORIGIN`.
2. Enforce version requirements during lookup using `DT_VERSYM`, `DT_VERNEED`, and provider version definitions.
3. Allocate dependency TLS and apply TLS relocations.
4. Initialize IFUNC/IRELATIVE resolvers and constructors in dependency order through bounded `ocall` records.
5. Apply final RELRO/protections and enter the main object without native-interpreter dependency loading.
