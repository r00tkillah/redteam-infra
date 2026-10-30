# Revised Native ELF Loader Roadmap

## Scope and acceptance boundary

The loader accepts user-selected x86-64 ELFs. Inputs are trusted by the user of
the tool; deliberate GNU version-hash collisions are out of scope.

- Accept interpreter-free static ET_EXEC binaries.
- Accept interpreter-free static PIE binaries and allow their entry stubs to
  perform self-relocation.
- Accept dynamically linked glibc binaries whose interpreter basename is
  `ld-linux-x86-64.so.2`.
- Reject all other dynamic interpreters, including dynamic musl.
- Support stripped glibc binaries by transferring to ELF `e_entry`; never
  depend on `.symtab` or finding `main`.
- Select glibc runtime adapters by exact interpreter build ID and fail closed
  for unknown build IDs.

## Current clean checkpoint

The committed worktree supports recursive dependency discovery, object mapping,
inode deduplication, GNU/SysV symbol lookup, relative and core symbolic
relocations, static TLS/DTV construction, static-musl ET_EXEC and static-PIE
entry, initial-stack construction, and interpreter-family gating.

Important commits are:

- `f2bf3dc`: gate self-transfer interpreter families.
- `874f3ed`: support static-musl PIE self-relocation.
- `2c2a735`: derive the runtime program-header address correctly.

Do not reintroduce the abandoned uncommitted `vmatch` opcode scaffold. Start
from a clean `git status --short`.

## Step-by-step implementation plan

### 1. Add bounded GNU version-hash matching

1. Keep `VERSYM` lookup for the requesting relocation symbol.
2. Treat version indexes 0 and 1 as unversioned/default and permit normal
   global lookup.
3. Traverse at most `min(DT_VERNEEDNUM, 16)` `Verneed` records.
4. For each record, traverse at most `min(vn_cnt, 16)` `Vernaux` records.
5. Select the `Vernaux` whose masked `vna_other` equals the requester version
   index and retain its `vna_hash`.
6. Traverse at most `min(DT_VERDEFNUM, 48)` provider `Verdef` records.
7. Select the record whose masked `vd_ndx` equals the provider symbol version
   index and require `vd_hash == vna_hash`.
8. Reject absent, malformed, out-of-map, or nonmatching version records.
9. Keep the implementation compact enough that `--rounds 2` transformed ELF
   execution retains `validate_status:1`. Prefer a one-time per-relocation hash
   cache in unused workspace cells over expanding nested lookup words at every
   provider candidate.
10. Add a wrong-version shared library exporting the same symbol under a
    different version hash before the correct provider. Prove the wrong object
    is skipped and the correct relocation is selected.

Checkpoint: run the full `make test` suite and commit version-hash enforcement.

### 2. Audit and finalize static TLS

1. Confirm PT_TLS records are bounded and alignment is nonzero/power-of-two.
2. Confirm every DTPMOD/DTPOFF/TPOFF write uses the provider's assigned module
   and template offset.
3. Verify DTV slots correspond to the assigned module identifiers, including
   gaps caused by objects without PT_TLS.
4. Add initialized `.tdata` and zero `.tbss` checks to both glibc and static
   musl fixtures.
5. Verify `FS:0` self, DTV pointer, stack guard, and DTV generation fields needed
   by the supported startup paths.

Checkpoint: run focused TLS tests and full `make test`; commit only if both pass.

### 3. Add the glibc adapter registry

1. Extract the interpreter GNU build ID from `PT_NOTE`/GNU property notes.
2. Define a bounded adapter record containing exact build ID and only the
   offsets/layout facts needed by IFUNC startup.
3. Add the current environment's glibc 2.39 adapter first.
4. Populate CPU/runtime fields using ELF-visible data plus the existing `cpuid`
   primitive; do not infer adapters from glibc version strings.
5. Reject unknown build IDs before any resolver call.
6. Make the registry additive so layouts can be shared only after byte-for-byte
   verification against every build ID assigned to them.

Checkpoint: test known-build selection and synthetic unknown-build rejection,
then commit the adapter framework separately from later adapter data.

### 4. Resolve IFUNC and IRELATIVE records

1. Delay RELRO and final read/execute protections for self-linked glibc mode.
2. Retain bounded resolver target, resolver address, and owning-object records.
3. Temporarily protect only resolver-bearing code as executable.
4. Activate target TLS immediately before each native resolver call and restore
   harness TLS immediately after return.
5. Invoke each resolver through bounded object-relative call records.
6. Write the resolver return value into its relocation target.
7. Process all required glibc/interpreter IRELATIVE records, not just the first.
8. Abort before constructors if any required relocation remains unresolved.

Checkpoint: prove zero required unresolved relocations for the current glibc
graph, test a known IFUNC result, run `make test`, and commit.

### 5. Run constructors in dependency order

1. Build a bounded dependency-order constructor queue.
2. Run dependency `DT_INIT`, followed by each nonzero `DT_INIT_ARRAY` entry in
   forward array order.
3. Run the main object's initialization last.
4. Use the same temporary target-TLS call mechanism as IFUNC resolution.
5. Ensure a constructor executes once even when its object has multiple inbound
   dependency edges.
6. Add fixture assertions for constructor output and constructor-initialized TLS.

Checkpoint: verify constructor/TLS behavior without the native interpreter,
run `make test`, and commit.

### 6. Apply final protections and enter the original program

1. Apply PT_GNU_RELRO only after all native calls and relocation writes.
2. Apply final PT_LOAD protections with executable permissions only where PF_X
   requests them.
3. Build the initial stack with correct `AT_PHDR`, `AT_PHENT`, `AT_PHNUM`,
   `AT_ENTRY`, `AT_RANDOM`, IDs, environment, and arguments.
4. Activate the final target TCB and jump to the original `e_entry`.
5. Do not locate or call `main` directly.
6. Prove dependency loading is not delegated to the Forth-mapped interpreter.

Checkpoint: verify output, arguments, environment, TLS, and final protection
records; run `make test` and commit.

### 7. Build and verify the libc matrix

1. Acquire package artifacts/sysroots for these baselines:
   - glibc 2.17: RHEL/Oracle Linux 7
   - glibc 2.28: RHEL/Oracle Linux 8
   - glibc 2.31: Ubuntu 20.04
   - glibc 2.34: RHEL/Oracle Linux 9
   - glibc 2.35/2.36: Ubuntu 22.04/Debian 12
   - glibc 2.39: Ubuntu 24.04/current environment
2. Add configurable bounded system-library roots so each package set can be
   tested without installing it as the host libc.
3. Record exact interpreter build IDs and add adapters only after that artifact
   passes IFUNC and startup tests.
4. Test both unstripped and `strip --strip-all` programs at original `e_entry`.
5. Test private dependencies, versioned symbols, constructors, initialized TLS,
   arguments, and environment.
6. Test static and static-PIE musl entry.
7. Test dynamic-musl and unknown-glibc rejection.
8. Run the complete regression suite.

Checkpoint: commit adapter additions in small release-family groups. Step 7 is
complete only when all matrix entries pass and the worktree is clean.
