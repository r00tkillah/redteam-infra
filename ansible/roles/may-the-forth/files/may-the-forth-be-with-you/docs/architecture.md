# Architecture

This loader centers on a Forth VM with polymorphic execution: Forth source is compiled into tokens, transformed in seeded rounds, validated, and then executed as the transformed stream.

It has four major subsystems:

1. A tiny Forth VM compiled as flat shellcode.
2. Callable and standalone runners that allocate and invoke it locally.
3. A Forth-controlled ELF mapping, relocation, protection, stack, and entry path.
4. Reference dry-loading and optional behavior-observation utilities.

Loader behavior is expressed in Forth so its policy and implementation are both
subject to seeded polymorphic execution. The callable C/Python path may supply
ELF bytes and generic OS callbacks but does not own ELF binding policy. The
standalone and embedded paths provide their own syscall services and require no
executable host callbacks.

## Data Flow

```text
Forth source (development) -> packed token artifact (production)
  -> C/Python callable runner or C/Python/Ruby/Perl standalone runner
  -> executable VM/bundle mapping
  -> seeded polymorphic transform rounds
  -> validated transformed stream
  -> VM execution
  -> output + metadata
  -> optional Forth ELF mapping and entry transfer
  -> optional benign payload telemetry
  -> optional C reference ELF dry-loader telemetry
  -> BCC JSONL events
  -> correlation rules
```

## Main Components

`src/forth_vm.asm` is the VM. It is assembled as an ELF object only as an intermediate build artifact, then `.text` is extracted to `build/forth.bin`.

`harness/c_harness.c` is the main research harness. It loads the shellcode blob, prepares executable anonymous memory, invokes the VM, passes optional ELF buffers into the workspace, runs benign payload scenarios, and performs the C reference ELF dry-load.

`harness/py_harness.py` gives a second shellcode invocation path for parity checks.

`harness/standalone_launcher.c` maps callback-free pathname-backed or embedded
artifacts. `harness/py_harness.py` also transfers embedded bundles. The Ruby
runner uses standard-library `Fiddle` for an ordinary null-argument call. The
core-Perl runner uses a 20-byte CET/IBT-compatible signal wrapper, `rt_sigaction`,
and `tgkill`; the wrapper jumps into the unchanged embedded bundle.

`tools/probe_bcc.py` attaches kprobes/kretprobes and emits JSONL. It captures memory mapping, file I/O, and process execution events.

`detections/rules.py` correlates the probe output into higher-level findings.

## Build Outputs

`build/` is intentionally disposable. It contains generated binaries, shellcode blobs, and probe JSONL output. It should not be committed.

Important outputs:

- `build/forth.bin`: source-free production VM plus the compact packed loader.
- `build/forth_dev.bin`: development VM with the textual Forth compiler.
- `build/elf64_dryload.fthp`: compact packed operational loader tokens.
- `build/elf64_dryload.instrumented.fthp`: packed tokens retaining report metrics.
- `build/c_harness`: primary local loader.
- `build/standalone_loader.bin`: callback-free pathname-backed loader.
- `build/standalone_loader.template.bin`: static embedded-bundle template.
- `build/go_static.bundle`: runnable embedded static Go example.
- `build/go_static.signal.bundle`: signal-entry form of the same Go example.
- `build/hello_dynamic`: benign dynamically linked demo ELF.
- `build/hello_static`: benign static demo ELF.
- `build/benign_control`: benign baseline for live probe control runs.

## Why Multiple Runners?

The C harness remains the complete research host and reference implementation.
Python supplies compilation/execution parity and embedded transfer. C/Python
can pass optional argument/environment data to embedded targets. Ruby proves
an ordinary standard-library FFI caller is sufficient. Perl proves a minimal
distribution can enter the same loader without FFI or CPAN modules.

## Why A Forth Loader Vocabulary?

The central research idea is that a dense interpreter vocabulary can express
loader behavior inside the shellcode VM and execute it through seeded
semantic-preserving token transforms. The VM exposes generic bounded byte
access, scratch/object storage, mapping/protection/copy services, and native
entry mechanisms. ELF constants, field layouts, validation, graph discovery,
hash/version lookup, relocation policy, TLS, constructors, and entry selection
remain in Forth.

Production expands a token-aware packed artifact, validates it, transforms it,
and runs it without textual parsing or dictionary construction. Development
uses the same VM core with textual compilation enabled and deterministically
regenerates both packed variants. `make packed-parity` locks the transformed
instrumented artifact to the source for fixed seeds; `make boundary-check`
rejects ELF format knowledge in assembly.

The C dry-loader is retained as an oracle and telemetry scaffold.

## Operational Versus Reference Paths

`--elf-forth ... --forth-transfer` is the operational path. Static and static-PIE images enter directly. Dynamic PIE currently enters through the mapped native interpreter. The C dry loader stops before control transfer and remains useful for comparison.

The embedded-static production path concatenates the same standalone VM and
packed Forth loader with an interpreter-free ELF. Its RIP-relative manifest
selects a bounded memory source, after which it converges with ordinary Forth
object processing. The shellcode runner only maps the complete bundle, passes
optional argument/environment data, and calls byte zero. Static policy and
`PT_INTERP` rejection stay in Forth; assembly owns manifest bounds and the
syscall-backed entry transfer.
