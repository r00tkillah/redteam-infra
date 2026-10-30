# Standalone loader measurements

Current snapshot: 2026-10-15, after embedded-static and Ruby/Perl runner
support. All values are generated artifacts and may move with Forth changes.
Rerun `make build ruby-perl-runner-test` before measuring.

| Artifact | Purpose | Bytes |
|---|---|---:|
| `build/forth_dev.bin` | Development VM and textual compiler | 53,104 |
| `build/forth.bin` | Callable source-free VM with compact loader | 31,080 |
| `build/elf64_dryload.fthp` | Compact packed Forth loader | 16,562 |
| `build/elf64_dryload.instrumented.fthp` | Telemetry-preserving packed loader | 16,804 |
| `build/standalone_loader.bin` | Pathname-backed callback-free loader | 30,664 |
| `build/standalone_loader.template.bin` | Static bundle template and manifest | 31,096 |
| `build/go_static.bundle` | Template plus static Go acceptance target | 1,436,150 |
| `build/go_static.signal.bundle` | Same bundle plus Perl signal entry | 1,436,170 |

The current textual loader compiles to 1,913 top-level tokens and 3,412 tokens
across 139 callable bodies. Compact production removes reporting call/literal
pairs and stores 1,895 top-level plus 3,396 body tokens. The ordinary runtime
token representation is 16 bytes per token; production expands the packed
artifact into the fixed 2 MiB workspace before transformation.

The standalone path has its own bounded 8 KiB return/output mapping and 1 MiB
target-stack allocation. The embedded template adds 432 bytes over the
pathname-backed standalone blob for its manifest entry, validation, default
argument path, and memory-backed acquisition initialization. The Perl form
adds only the 20-byte `endbr64`, signal-argument, jump, and `rt_sigreturn`
wrapper; the underlying loader and ELF bytes are unchanged.

`make standalone-test` checks pathname-backed static, musl, glibc, private
dependency, TLS, constructor, argument/environment, version, fail-closed,
W^X, and relocation-free behavior. `make embedded-static-test` checks C/Python
byte-zero static transfer and blocked post-acquisition file/exec syscalls.
`make ruby-perl-runner-test` adds repeated Ruby direct calls, Perl signal entry,
CET/IBT, unavailable-FFI and signal errors, and syscall/W^X auditing.
`make matrix-test` checks standalone transfer across glibc 2.17, 2.28, 2.31,
2.34, 2.35, and 2.36.
