# Forth VM Shellcode ABI

`src/forth_vm.asm` implements a small position-independent Forth VM with polymorphic execution. The build extracts its `.text` into a flat shellcode blob at `build/forth.bin`.

The VM compiles Forth source into tokens, applies seeded semantic-preserving transform rounds, validates the transformed token stream, and executes the transformed stream.

## Calling Convention

The harness calls the blob with this x86_64 ABI:

```text
rdi: input buffer pointer
rsi: input length
rdx: output buffer pointer
rcx: output capacity
r8:  workspace pointer
r9:  workspace length
rax: bytes written, or negative error code
```

The VM does not call libc.

## Workspace

The workspace is shared scratch memory supplied by the harness. It contains:

- a metadata header,
- the VM data stack,
- the original token stream,
- the final transformed token stream,
- trace records,
- a scratch token stream for multi-round transforms,
- a bounded non-executable image buffer used by the Forth ELF dry loader,
- a compile-time dictionary for constants and inline words while source is being compiled.

The current layout gives the Forth scratch area 256 cells and gives the original token stream enough room for the branch-heavy ELF dry-loader script. That expansion was driven by the dynamic-link dry-plan work rather than by a new native ELF opcode.

The layout is defined in three places:

- `include/workspace.inc` for NASM,
- `include/workspace.h` for C,
- `tools/workspace_layout.py` for Python.

Keeping these synchronized is important. A future cleanup should generate them from one source of truth.

## Supported Words

```text
: name ... ; constant
dup drop swap over + - * = < > . emit cr negate 0= 1+ 1- invert 2*
and or xor lshift rshift u< u> min max
m@ m! u/ i8@ i8! i64@ i64! ecopy
for i next if else then
ebase elen u8 u16 u32 u64
```

The development compiler also recognizes `N layout`, `cell NAME`,
`N array NAME`, `N fields`, `field NAME`, `width NAME`, and
`N records NAME`. These compile-time-only definitions emit no runtime tokens
and fail on overflow. `N union` visibly starts an arena that intentionally
reuses earlier storage while retaining the high-water mark for later monotonic
allocations. Production blobs consume the packed result and do not carry these
compiler words.

The VM supports bounded integer parsing, token scanning, a fixed-size stack, and bounded output.

The generic `u*` words read from the optional selected source buffer. ELF
offsets and field accessors are defined in Forth, not in the VM.

The bitwise and unsigned words are deliberately generic. They let Forth source own loader-specific details such as flag extraction, relocation type extraction, and unsigned offset/size checks.

`m@` and `m!` access a bounded VM scratch-cell area in the workspace:

```text
index m@      ( -- value )
value index m! ( -- )
```

The ELF loader script uses those cells for loader state such as segment counts, dynamic-table offsets, relocation-table pointers, string/symbol/hash/version table pointers, dependency records, relocation records, and load-plan records. `u/` is unsigned integer division and is used for bounded table entry counts.

Source/object and OS-service words are intentionally generic:

```text
object offset o8@                 ( -- value )
object offset o64@                ( -- value )
object offset ocall               ( -- result )
value object offset o64!          ( -- )
source_off object_off n object ecopy ( -- )
hint n prot flags osmap           ( -- address )
address n osunmap                 ( -- status )
address n prot osprot             ( -- status )
path-address path-length source-slot capacity osread ( -- handle/status )
handle osclose                    ( -- status )
pbase                             ( -- path-address )
path-offset p8@                   ( -- byte )
byte path-offset p8!              ( -- )
source-slot esource               ( -- )
```

Object records declare source and destination bounds. `ecopy` and object reads/writes enforce those bounds, while the harness callbacks perform only generic OS operations. `osread` opens exactly the Forth-supplied path, rejects oversized files, fills only an empty selected source slot, and returns the handle for `osclose`; it performs no path search. `esource` selects a populated source record for all subsequent bounded `u8`/`u16`/`u32`/`u64` reads and rejects empty or oversized records. A separate 4 KiB path buffer with `p8@`/`p8!` prevents path construction from overlapping transformed code. ELF policy and the choice of final mapping address remain in Forth.

`constant` is compile-time only. The pattern `64 constant NAME` removes the preceding literal from the runtime token stream and records `NAME` in a temporary compile dictionary. Later uses of `NAME` compile to a literal value.

Colon definitions are also compile-time inline definitions in this VM. The pattern `: name ... ;` stores a token body in the compile dictionary, and later uses of `name` expand those tokens into the current program. This gives dense Forth source without introducing a runtime call/return stack yet.

The counted loop form is intentionally small:

```text
count for i ... next
```

`for` consumes a runtime count, `i` pushes the current zero-based loop index, and `next` advances until the index reaches the count. The current implementation supports one active counted loop at a time, which is enough for the Forth ELF script to iterate `e_phnum` program headers without adding ELF-specific iteration opcodes. The transformer repairs `for`/`next` relative offsets after each transform round, so variable-length transforms inside loop bodies can still execute from the transformed stream.

Conditionals use the usual source form:

```text
flag if ... else ... then
flag if ... then
```

`if` consumes a Forth truth value, where zero is false and nonzero is true. `else` is optional. The compiler emits branch tokens and a no-op `then` boundary token so the transformer can repair branch offsets after polymorphic expansion.

## Errors

The VM returns negative error codes for:

- unknown word,
- stack underflow,
- bad number,
- output overflow,
- workspace too small,
- unsigned division by zero.

The harness reports both `rax` and metadata fields such as validation status, error offset, max stack depth, and final stack depth.

## Shellcode Build Flow

```sh
nasm -f elf64 src/forth_vm.asm -o build/forth_vm.o
objcopy -O binary -j .text build/forth_vm.o build/forth.bin
readelf -r build/forth_vm.o
```

`readelf -r` should report no relocations.
