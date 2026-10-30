# AArch64 Future Direction

AArch64 is the preferred second architecture. It preserves the current ELF64
and 64-bit-cell model, so it is an architecture port rather than a new loader
design. ARM32 is not a target.

## Reusable Architecture

The following should remain shared with x86-64:

- packed Forth source and token format;
- workspace, object graph, bundle manifest, and bounded memory-source model;
- ELF64 header/program-header policy where fields are architecture-neutral;
- segment mapping, load-bias, BSS, W^X, RELRO, and entry selection policy;
- static ET_EXEC and interpreter-free static-PIE packaging;
- seeded transformation, validation, compact/instrumented builds, and
  source-free production loading; and
- C/Python/Ruby direct-entry and core-Perl signal-entry deployment concepts.

Architecture-dependent constants and decisions must remain in Forth. Generic
execution/syscall mechanisms belong in the AArch64 VM implementation.

## Required Porting Work

Create a position-independent AArch64 VM implementing the same packed decoder,
token validator, transform engine, operand/return stacks, and opcode semantics.
Port native mapping, protection, copying, file acquisition, TLS installation,
native calls, and final entry transfer to the Linux AArch64 syscall and calling
conventions.

Add `EM_AARCH64` policy and the static relocation families actually emitted by
the selected AArch64 toolchains, beginning with `R_AARCH64_RELATIVE`. Do not
broaden native relocation knowledge in advance; unsupported forms should fail
closed through Forth policy.

The initial stack must include correct AArch64 auxiliary-vector values. In
particular, preserve or derive `AT_HWCAP` and `AT_HWCAP2`, since language
runtimes such as Go use them for CPU-feature selection. Audit TLS layout,
thread-pointer setup, and target entry register state against the AArch64 ELF
ABI.

Explicitly synchronize the instruction cache after generating transformed VM
code or populating executable object pages. Do not assume x86-style coherent
instruction-cache behavior.

## Runner Implications

The C/Python and Ruby runners still allocate RW memory, copy one opaque bundle,
change it to RX, and make a null-argument call. Their address and integer types
need only be checked against 64-bit AArch64 ABIs.

The core-Perl path needs an AArch64-specific prefix and signal setup. Its
indirect landing must support BTI-enabled processes, clear `x0`, and branch to
the unchanged loader. Syscall numbers, kernel `sigaction` layout, signal
restorer convention, and instruction-cache synchronization must be derived
from the AArch64 UAPI rather than copied from x86-64.

## Suggested Milestones

1. Run the basic Forth arithmetic/stack corpus in an AArch64 C harness.
2. Establish packed parity and seeded transform validation.
3. Transfer a syscall-only static ET_EXEC fixture.
4. Support interpreter-free static PIE and AArch64 relative relocations.
5. Transfer a real `CGO_ENABLED=0 GOOS=linux GOARCH=arm64` fixture with
   arguments, environment, allocation, goroutines, TLS, and time access.
6. Package and run it as a self-contained bundle through C, Python, and Ruby.
7. Add and audit the AArch64 core-Perl signal-entry variant.
8. Run equivalent boundary, W^X, malformed-input, ASLR, and syscall-denial
   gates before considering pathname-backed dynamic objects.

Dynamic AArch64 execution is deliberately subsequent work. It should begin
only after the callback-free embedded static path passes on native hardware and
under the chosen CI/emulation environment.
