# Forth Dynamic Linker Architecture Plan

## Goal

Make Forth own the complete ELF loading state machine: object discovery, mapping,
symbol/version lookup, relocation, protection, initialization, and entry transfer.
The harness remains responsible only for generic OS operations requested by Forth.

## Architecture Changes

1. Replace the single fixed image assumption with an object arena and object table.
   Each object records source bytes, load mapping, virtual-address bounds, dynamic
   metadata, dependency state, and final protections.
2. Allocate every object at its final address before relocation. Expose generic
   `map`, `unmap`, `protect`, `read-file`, and `close` VM services; do not expose
   `dlopen`, `dlsym`, or ELF-specific C helpers.
3. Pass service function pointers through the VM workspace ABI. Calls return only
   scalar status, handles, and addresses. All ELF interpretation remains Forth.
4. Replace `ecopy`'s implicit workspace image destination with bounded copies into
   the selected object's final mapping.
5. Add Forth object and dependency walks, including interpreter-first breadth-first
   discovery, duplicate suppression, and `DT_NEEDED` search rules.
6. Implement SysV and GNU hash lookup in Forth. Apply ELF global/weak precedence,
   visibility, undefined-symbol handling, and `DT_VERSYM`/`DT_VERNEED` matching.
7. Implement x86-64 RELA relocation in Forth, initially `RELATIVE`, `GLOB_DAT`,
   `JUMP_SLOT`, and `R_X86_64_64`, then COPY, IRELATIVE, and TLS families.
8. Apply RELRO and final segment protections only after relocation. Run dependency
   constructors in dependency order.
9. Build a Linux initial stack and auxiliary vector containing final `AT_PHDR`,
   `AT_PHNUM`, `AT_ENTRY`, and `AT_BASE`, then transfer to the interpreter entry.

## Incremental Implementation Plan

Each increment must fit in one working turn, have one observable output, and leave
the test suite passing. Do not combine an increment with the next one.

### Capacity and object foundation (complete)

- **1.1 Workspace capacity:** enlarge the source, object-data, transform, and
  scratch regions. Add compile-time overlap checks in C and assembly.
- **1.2 Layout parity:** export the same offsets to Python and test that the final
  region ends exactly at the workspace boundary.
- **2.1 Object record ABI:** reserve bounded fields for source address/length,
  mapping address/length, virtual-address range, entry, and state.
- **2.2 Generic callback ABI:** install `map`, `unmap`, `protect`, `read-file`, and
  `close` callbacks in the workspace for C and Python.
- **2.3 Forth-owned main mapping:** make Forth request the main object's final RW
  mapping and reject executable mapping requests.
- **2.4 Direct object copies:** make `ecopy` copy into a selected object record with
  source and destination bounds checks.
- **2.5 In-place reads/writes:** read relocation data from the object and apply
  `RELATIVE` writes in its final mapping.

### Source acquisition and path construction

- **3.1 Read-file contract:** redefine/document `read-file` as an exact path-based
  operation that fills a selected bounded source slot and returns only a handle or
  scalar error. The callback performs no search or ELF interpretation.
- **3.2 Byte-addressed path buffer:** add generic bounded byte read/write operations
  for a designated workspace path buffer. Test append, termination, and overflow.
- **3.3 Exact-file smoke test:** have Forth construct one fixed absolute fixture path,
  acquire it through `read-file`, validate its byte count, and close its handle.
- **3.4 Source selection:** add a Forth-visible operation that selects any populated
  source slot for the existing bounded ELF reads. Reject empty and oversized slots.

### Interpreter discovery

- **3.5 Interpreter path extraction:** copy `PT_INTERP` from object 0 into the path
  buffer and emit its length and bytes from Forth.
- **3.6 Interpreter acquisition:** read the exact interpreter path into source slot 1
  and close the returned handle. Do not parse or map it yet.
- **3.7 One-pass object parser:** refactor the main-object logic to accept source and
  object indexes from persistent cells rather than hard-coded object 0.
- **3.8 Interpreter mapping:** run the one-pass parser for source/object 1, request its
  final RW mapping, and verify two callback-issued mappings.

### Dependency discovery

- **3.9 Needed-name extraction:** copy each direct `DT_NEEDED` basename into a bounded
  name queue with duplicate suppression. Test names but do not acquire files.
- **3.10 Candidate builder:** construct one candidate as `directory + '/' + name`
  entirely in Forth and verify its exact bytes and overflow behavior.
- **3.11 Search directory records:** represent loader directory, `RPATH`, `RUNPATH`,
  environment directories, and default directories as ordered Forth data.
- **3.12 Single dependency acquisition:** try candidates for one queued basename,
  store the first successful source slot, and record deterministic failures.
- **3.13 Persistent breadth-first step:** process exactly one pending object per VM
  invocation, append unseen dependencies, and update queue head/tail cells.
- **3.14 Fixed-point driver:** invoke the same Forth state machine until its scalar
  state is done or failed. The harness observes state only and makes no decisions.
- **3.15 Discovery completion:** verify the main ELF, interpreter, and complete
  transitive dependency set are mapped once, non-executable, and Forth-requested.

### Symbol lookup and relocation

- **4.1 SysV hash lookup:** implement and test lookup against one synthetic table.
- **4.2 GNU hash lookup:** implement and test bloom, bucket, and chain bounds.
- **4.3 Global/weak selection:** search object scope in order and implement defined,
  undefined, global, weak, and visibility rules.
- **4.4 Version records:** parse `VERSYM` and `VERNEED` and match one requested version.
- **4.5 Core symbolic relocations:** apply `GLOB_DAT`, `JUMP_SLOT`, and `R_X86_64_64`
  with target and symbol bounds checks.
- **4.6 Additional relocation families:** add COPY, IRELATIVE, and TLS one family per
  later increment, each with its own fixture.

### Protection and startup

- **5.1 RELRO:** issue bounded `protect` callbacks for RELRO after relocation.
- **5.2 Segment protections:** apply final segment permissions and verify no object
  becomes executable before relocation completes.
- **5.3 Constructor order:** compute dependency order and call constructors in that
  order with a minimal fixture.
- **5.4 Initial stack:** build `argc`, `argv`, `envp`, and an auxiliary vector with
  final `AT_PHDR`, `AT_PHNUM`, `AT_ENTRY`, and `AT_BASE`.
- **5.5 Entry transfer:** transfer to the interpreter entry and verify target output.

### Verification hardening

- **6.1 Object varieties:** add PIE and ET_EXEC dynamic fixtures.
- **6.2 Binding cases:** add constructor, global/weak, version, and missing-symbol
  fixtures.
- **6.3 Malformed inputs:** independently test every source, object, table, string,
  relocation, path, and queue bound.
- **6.4 Dependency failures:** test missing files, cycles, duplicate basenames, and
  object/source capacity exhaustion.
- **6.5 Polymorphism:** run all discovery/binding/startup fixtures across a seed matrix
  and at least two transformation rounds.

## Invariants

- Forth never reads or writes outside a declared source/object mapping.
- Every relocation target belongs to the object being relocated.
- No executable mapping exists before validation and relocation complete.
- No ELF-specific loading or binding decision occurs in the harness.
- Execution tests prove both Forth-issued operations and target output.
