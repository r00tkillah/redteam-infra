0 constant EI-MAGIC
4 constant EI-CLASS
5 constant EI-DATA
16 constant E-TYPE
18 constant E-MACHINE
24 constant E-ENTRY
32 constant E-PHOFF
54 constant E-PHENTSZ
56 constant E-PHNUM
0 constant PH-TYPE
4 constant PH-FLAGS
8 constant PH-OFFSET
16 constant PH-VADDR
32 constant PH-FILESZ
40 constant PH-MEMSZ
48 constant PH-ALIGN
1 constant PT-LOAD
2 constant PT-DYNAMIC
3 constant PT-INTERP
4 constant PT-NOTE
7 constant PT-TLS
1685382482 constant PT-RELRO
1179403647 constant ELFMAG
2 constant ELFCLASS64
1 constant ELFDATA2LSB
62 constant EM-X86-64
1 constant PF-X
2 constant PF-W
4 constant PF-R
0 constant DT-NULL
1 constant DT-NEEDED
2 constant DT-PLTRELSZ
4 constant DT-HASH
5 constant DT-STRTAB
6 constant DT-SYMTAB
7 constant DT-RELA
8 constant DT-RELASZ
9 constant DT-RELAENT
10 constant DT-STRSZ
11 constant DT-SYMENT
12 constant DT-INIT
17 constant DT-REL
18 constant DT-RELSZ
19 constant DT-RELENT
20 constant DT-PLTREL
23 constant DT-JMPREL
25 constant DT-INIT-ARRAY
27 constant DT-INIT-ARRAYSZ
15 constant DT-RPATH
29 constant DT-RUNPATH
35 constant DT-RELRSZ
36 constant DT-RELR
37 constant DT-RELRENT
1879047925 constant DT-GNU-HASH
1879048176 constant DT-VERSYM
1879048190 constant DT-VERNEED
1879048191 constant DT-VERNEEDNUM
1879048188 constant DT-VERDEF
1879048189 constant DT-VERDEFNUM
8 constant R-REL
7 constant R-JUMP
6 constant R-GLOB
1 constant R-64
37 constant R-IREL
16 constant R-DTPMOD
17 constant R-DTPOFF
18 constant R-TPOFF
4294967295 constant R-MASK
32767 constant V-MASK
0 layout
cell S-LOADS
cell S-INTERP
cell S-DYNAMIC
cell S-BSS
cell S-DYNOFF
cell S-DYNSZ
cell S-DYNVA
cell S-NEEDED
cell S-RELA
cell S-RELASZ
cell S-REL
cell S-RELSZ
cell S-JMPREL
cell S-PLTRELSZ
cell S-PLTREL
cell S-STRTAB
cell S-SYMTAB
cell S-LOW
cell S-HIGH
cell S-SPAN
cell S-COPIED
cell S-RELA-TOTAL
cell S-RELATIVE
cell S-REL-APPLIED
cell S-SYMBOLIC
cell S-JUMP-SLOT
cell S-UNSUPPORTED
cell S-JMPREL-TOTAL
cell S-PLAN-MAPS
cell S-PLAN-PROT
cell S-PLAN-XPROT
cell S-PLAN-DEPS
cell S-PLAN-ENTRY
cell S-PLAN-TARGET
cell S-PLAN-RELOC
cell S-PLAN-REL-WR
cell S-PLAN-SYM
cell S-PLAN-BSS
cell S-PLAN-SPAN
cell S-PLAN-DONE
cell S-PNREC
cell S-PXREC
cell S-HASH
cell S-GNU-HASH
cell S-STRSZ
cell S-SYMENT
cell S-VERSYM
cell S-VERNEED
0 fields
field P-KIND
field P-FLAGS
field P-MEMSZ
field P-FILESZ
field P-FINAL
field P-VADDR
field P-OFFSET
field P-PROT
width P-SIZE
6 constant P-MAX
6 records P-BASE
112 layout
0 fields
field N-STATE
field N-REQUESTER
field N-NAME
field N-ADDRESS
width N-SIZE
15 constant N-MAX
15 records N-BASE
175 layout
cell S-VERNEEDNUM
256 layout
0 fields
field O-STATE
field O-SOURCE-KIND
field O-SOURCE-ADDR
field O-SOURCE-SIZE
field O-MAP-BASE
field O-LOW
field O-HIGH
field O-ENTRY
field O-MAP-SIZE
field O-STRTAB
field O-SYMTAB
field O-HASH
field O-GNU-HASH
field O-VERSYM
field O-VERNEED
field O-SYMENT
width O-SIZE
48 records O-BASE
1024 layout
0 fields
field X-OFFSET
field X-VALUE
field X-INFO
field X-TARGET
field X-ADJUST
field X-NAME
width X-SIZE
96 constant X-MAX
96 records X-BASE
64 constant C-MAX
1024 union
34 fields
width Q-SIZE
15 constant Q-MAX
15 records Q-BASE
32 constant Q-NAME-MAX
128 constant SYM-NAME-MAX
1600 layout
48 array V-BASE
48 array VN-BASE
1687 union
cell S-LIBC
cell S-CONSTRUCTORS
cell S-IFUNC-CALLS
cell S-IFUNC-RESULT
cell S-NATIVE-RESULTS
cell S-ADAPTER
cell S-NATIVE-CALLS
cell S-NATIVE-PENDING
cell S-RCALL
1696 layout
cell S-MAIN-PATH-LEN
cell S-VHASH
cell S-VPTR
cell S-VAUX
cell U-PHASE-0
cell U-PHASE-1
cell U-PHASE-2
U-PHASE-0 constant S-DIR-LEN
U-PHASE-1 constant S-RUNPATH
U-PHASE-2 constant S-ORIGIN-ACTIVE
U-PHASE-0 constant S-VCOUNT
U-PHASE-1 constant S-VINDEX
U-PHASE-2 constant S-VMAL
3840 constant MAIN-PATH
cell S-VPRESENT
cell S-TLS-TOTAL
cell S-TLS-BASE
cell S-HIDX
cell S-TCB-BASE
cell S-STAGE64
cell S-MUSL
0 fields
field TLS-VADDR
field TLS-FILESZ
field TLS-MEMSZ
field TLS-ALIGN
width TLS-SIZE
12 records TLS-BASE
0 fields
field INIT-FUNC
field INIT-ARRAY
field INIT-ARRAYSZ
width INIT-SIZE
10 records INIT-BASE
1790 layout
cell S-QUEUE-TAIL
cell T-Q
cell T-B
cell S-NAME-UNIQUE
cell S-NAME-COUNT
cell S-PHASH
cell S-PROVIDER
cell S-PGNU
cell S-PNB
cell S-PBLOOM
1821 layout
cell S-XFER-MODE
48 array Y-BASE
48 array W-BASE
12 array I-BASE
cell S-GNU-CAND
cell S-GNU-NONEMPTY
cell S-GNU-HMATCH
cell S-CHAIN-VISIT
cell S-CHAIN-MATCH
cell S-PROVIDERS
cell S-RIDX
cell S-POBJ
cell S-CUR-SYM
cell S-NAME-MATCH
cell S-RESOLVED
cell S-PROTECTED
cell S-RELRO-PROT
cell S-REQUIRED
cell S-WEAK-MISSING
cell S-REQ-SYM
cell U-RELR-IREL
U-RELR-IREL constant S-RELR-NEXT
U-RELR-IREL constant S-IREL-COUNT
cell S-LINK-PHASE
cell S-CURRENT-SOURCE
cell S-CURRENT-OBJECT
0 fields
field A-LO
field A-HI
field A-HASH
field A-VALUE
field A-VERSION
field A-OFFSET
field A-SIZE-END
width A-SIZE
7 constant A-MAX
7 records A-BASE
0 fields
field AR-START
field AR-END
width AR-SIZE
7 records AR-BASE
80 union
0 fields
field RCV-TARGET
field RCV-RESOLVER
field RCV-RESULT
width RCV-SIZE
58 constant RCV-MAX
58 records RCV-BASE
1 constant OM-ANON
2 constant OM-FIXED

: ph-base E-PHOFF u64 swap E-PHENTSZ u16 * + ;
: ph-addr swap ph-base + ;
: ph-u32 ph-addr u32 ;
: ph-u64 ph-addr u64 ;
: ph-perms PH-FLAGS ph-u32 ;
: ph-x ph-perms PF-X and ;
: ph-w ph-perms PF-W and ;
: ph-r ph-perms PF-R and ;
: ph-prot
  dup ph-r 0 > negate swap dup ph-w 0 > negate 2 * swap
  ph-x 0 > negate 4 * + + ;
: e-magic EI-MAGIC u32 ;
: e-class EI-CLASS u8 ;
: e-data EI-DATA u8 ;
: e-machine E-MACHINE u16 ;
: e-ok e-magic ELFMAG = e-class ELFCLASS64 = and e-data ELFDATA2LSB = and e-machine EM-X86-64 = and ;
: ph-type PH-TYPE ph-u32 ;
: ph-load? ph-type PT-LOAD = ;
: ph-interp? ph-type PT-INTERP = ;
: ph-dynamic? ph-type PT-DYNAMIC = ;
: ph-note? ph-type PT-NOTE = ;
: ph-relro? ph-type PT-RELRO = ;
: ph-tls? ph-type PT-TLS = ;
: ph-filesz PH-FILESZ ph-u64 ;
: ph-memsz PH-MEMSZ ph-u64 ;
: power2? dup 0 > swap dup 1 - and 0= and ;
: tls-ok? dup ph-filesz over ph-memsz u> invert swap PH-ALIGN ph-u64 power2? and ;
: ph-vaddr PH-VADDR ph-u64 ;
: ph-bss dup ph-memsz swap ph-filesz - ;
: ph-end dup ph-vaddr swap ph-memsz + ;
: inc@ dup m@ 1 + swap m! ;
: metric+ inc@ ;
: add@ swap over m@ + swap m! ;
: zero-stats
  0 S-LOADS m! 0 S-INTERP m! 0 S-DYNAMIC m! 0 S-BSS m!
  0 S-DYNOFF m! 0 S-DYNSZ m! 0 S-DYNVA m! 0 S-NEEDED m!
  0 S-RELA m! 0 S-RELASZ m! 0 S-REL m! 0 S-RELSZ m!
  0 S-JMPREL m! 0 S-PLTRELSZ m! 0 S-PLTREL m!
  0 S-STRTAB m! 0 S-SYMTAB m! 0 S-HASH m! 0 S-GNU-HASH m!
  0 S-STRSZ m! 0 S-SYMENT m! 0 S-VERSYM m! 0 S-VERNEED m! 0 S-VERNEEDNUM m!
  0 S-RUNPATH m!
  0 S-ORIGIN-ACTIVE m!
  -1 S-LOW m! 0 S-HIGH m! 0 S-SPAN m! 0 S-COPIED m! ;
: zero-relocs
  0 S-RELA-TOTAL m! 0 S-RELATIVE m! 0 S-REL-APPLIED m!
  0 S-SYMBOLIC m! 0 S-JUMP-SLOT m! 0 S-UNSUPPORTED m!
  0 S-JMPREL-TOTAL m! 0 S-GNU-CAND m! 0 S-GNU-NONEMPTY m!
  0 S-GNU-HMATCH m! 0 S-CHAIN-VISIT m! 0 S-CHAIN-MATCH m!
  0 S-NAME-MATCH m! 0 S-RESOLVED m! 0 S-PROTECTED m!
  0 S-REQUIRED m! 0 S-WEAK-MISSING m! 0 S-REQ-SYM m!
  0 S-RELRO-PROT m! ;
: zero-plan
  0 S-PLAN-MAPS m! 0 S-PLAN-PROT m! 0 S-PLAN-XPROT m!
  0 S-PLAN-DEPS m! 0 S-PLAN-ENTRY m! 0 S-PLAN-TARGET m!
  0 S-PLAN-RELOC m! 0 S-PLAN-REL-WR m! 0 S-PLAN-SYM m!
  0 S-PLAN-BSS m! 0 S-PLAN-SPAN m! 0 S-PLAN-DONE m!
  0 S-PNREC m! 0 S-PXREC m! ;
: p-cell P-SIZE * P-BASE + + ;
: p@ p-cell m@ ;
: plan-v! S-PLAN-MAPS m@ p-cell m! ;
: n-cell N-SIZE * N-BASE + + ;
: n@ n-cell m@ ;
: need-v! S-PNREC m@ n-cell m! ;
: need-can? S-PNREC m@ N-MAX u< ;
: need-img S-STRTAB m@ S-LOW m@ - + ;
: q-cell Q-SIZE * Q-BASE + + ;
: q@ q-cell m@ ;
: q! q-cell m! ;
: default-dir
  47 0 p8! 108 1 p8! 105 2 p8! 98 3 p8! 47 4 p8!
  120 5 p8! 56 6 p8! 54 7 p8! 95 8 p8! 54 9 p8! 52 10 p8!
  45 11 p8! 108 12 p8! 105 13 p8! 110 14 p8! 117 15 p8!
  120 16 p8! 45 17 p8! 103 18 p8! 110 19 p8! 117 20 p8! 47 21 p8!
  22 S-DIR-LEN m! ;
: musl-dir
  47 0 p8! 108 1 p8! 105 2 p8! 98 3 p8! 47 4 p8! 120 5 p8!
  56 6 p8! 54 7 p8! 95 8 p8! 54 9 p8! 52 10 p8! 45 11 p8!
  108 12 p8! 105 13 p8! 110 14 p8! 117 15 p8! 120 16 p8!
  45 17 p8! 109 18 p8! 117 19 p8! 115 20 p8! 108 21 p8! 47 22 p8!
  23 S-DIR-LEN m! ;
: system-dir S-MUSL m@ if musl-dir else default-dir then ;
: x-cell X-SIZE * X-BASE + + ;
: x@ x-cell m@ ;
: xi! x-cell m! ;
: o-cell S-CURRENT-OBJECT m@ O-SIZE * O-BASE + + ;
: o@ o-cell m@ ;
: o! o-cell m! ;
: oi-cell O-SIZE * O-BASE + + ;
: oi@ oi-cell m@ ;
: tls-cell S-CURRENT-OBJECT m@ TLS-SIZE * TLS-BASE + + ;
: stage64
  S-STAGE64 m! 8 for S-STAGE64 m@ i 8 * rshift 255 and i p8! next ;
: tls! tls-cell m! ;
: ti-cell TLS-SIZE * TLS-BASE + + ;
: ti@ ti-cell m@ ;
: ti! ti-cell m! ;
: tls-layout
  0 S-TLS-TOTAL m!
  12 for
    2 i ti@ 0 > if
      S-TLS-TOTAL m@ 3 i ti@ 1 - + 3 i ti@ u/ 3 i ti@ * dup S-TLS-TOTAL m!
      0 i ti@ R-MASK and swap 32 lshift + 0 i ti!
      3 i ti@ R-MASK and i 1 + 32 lshift + 3 i ti!
      S-TLS-TOTAL m@ 2 i ti@ + S-TLS-TOTAL m!
    then
  next
  S-TLS-TOTAL m@ 256 + 4095 + 4096 u/ 4096 * dup 0 > if
    0 swap 3 5 osmap S-TLS-BASE m!
  else drop then
  S-TLS-BASE m@ S-TLS-TOTAL m@ + 15 + 16 u/ 16 * S-TCB-BASE m!
  12 for
    1 i ti@ 0 > if
      4 i oi@ 0 i ti@ R-MASK and 5 i oi@ - +
      S-TLS-BASE m@ 0 i ti@ 32 rshift + 1 i ti@ oscopy drop
    then
  next
  S-TCB-BASE m@ stage64 pbase S-TCB-BASE m@ 8 oscopy drop
  S-TCB-BASE m@ 96 + stage64 pbase S-TCB-BASE m@ 8 + 8 oscopy drop
  S-TCB-BASE m@ stage64 pbase S-TCB-BASE m@ 16 + 8 oscopy drop
  1 stage64 pbase S-TCB-BASE m@ 96 + 8 oscopy drop
  11400714819323198485 stage64 pbase S-TCB-BASE m@ 48 + 8 oscopy drop
  12 16 * for
    i 16 u/ T-Q m! i dup 16 u/ 16 * - T-B m!
    S-TLS-BASE m@ 0 T-Q m@ ti@ 32 rshift +
    T-B m@ 8 * rshift 255 and
    T-B m@ 8 u< 2 T-Q m@ ti@ 0 > and negate * i p8!
  next
  pbase S-TCB-BASE m@ 112 + 192 oscopy drop
  12 stage64 pbase S-TCB-BASE m@ 80 + 8 oscopy drop ;
: init!
  S-VCOUNT m! S-VINDEX m!
  S-CURRENT-OBJECT m@ 10 u< if
    S-VCOUNT m@ S-CURRENT-OBJECT m@ INIT-SIZE * INIT-BASE + +
    dup m@ 32 rshift 32 lshift S-VCOUNT m@ 2 = negate * S-VINDEX m@ R-MASK and + swap m!
  then ;
: edge!
  dup 32 u< S-CURRENT-OBJECT m@ 10 u< and if
    S-VINDEX m! S-CURRENT-OBJECT m@ INIT-SIZE * INIT-BASE + 2 +
    dup m@ 1 S-VINDEX m@ lshift 32 lshift or swap m!
  else drop then ;
: ii@ INIT-SIZE * INIT-BASE + + m@ ;
: v! S-CURRENT-OBJECT m@ V-BASE + m! ;
: vn! S-CURRENT-OBJECT m@ VN-BASE + m! ;
: reloc-v! S-PXREC m@ x-cell m! ;
: rcv-cell RCV-SIZE * RCV-BASE + + ;
: rcv! S-RCALL m@ rcv-cell m! ;
: reloc-can? S-PXREC m@ X-MAX u< ;
: h@ 0 swap x@ ;
: h!
  S-HIDX m! S-HIDX m@ h@ 32 rshift 32 lshift + 0 S-HIDX m@ xi! ;
: r!
  S-HIDX m! 32 lshift S-HIDX m@ h@ R-MASK and + 0 S-HIDX m@ xi! ;
: a@ 1 swap x@ ;
: a! 1 swap xi! ;
: z@ 1 swap x@ ;
: z! 1 swap xi! ;
: umod over over u/ * - ;
: page-down 4096 u/ 4096 * ;
: page-up 4095 + page-down ;
: prov64 S-PROVIDER m@ swap o64@ ;
: p-bucket
  S-PROVIDER m! S-PHASH m!
  12 S-PROVIDER m@ oi@ 5 S-PROVIDER m@ oi@ - S-PGNU m!
  S-PGNU m@ prov64 R-MASK and S-PNB m!
  S-PGNU m@ 8 + prov64 R-MASK and S-PBLOOM m!
  S-PGNU m@ 16 + S-PBLOOM m@ 8 * +
  S-PHASH m@ S-PNB m@ umod 4 * + prov64 R-MASK and
  dup S-PBLOOM m! ;
: p-chain-at
  S-CUR-SYM m!
  S-PGNU m@ 16 + S-PGNU m@ 8 + prov64 R-MASK and 8 * +
  S-PNB m@ 4 * + S-CUR-SYM m@ S-PGNU m@ prov64 32 rshift - 4 * +
  prov64 R-MASK and ;
: p-sval
  10 S-POBJ m@ oi@ 5 S-POBJ m@ oi@ - S-CUR-SYM m@ 15 S-POBJ m@ oi@ * + 8 +
  S-POBJ m@ swap o64@ ;
: p-type
  10 S-POBJ m@ oi@ 5 S-POBJ m@ oi@ - S-CUR-SYM m@ 15 S-POBJ m@ oi@ * + 4 +
  S-POBJ m@ swap o8@ 15 and ;
: reloc-value
  S-RIDX m! S-RIDX m@ h@ 32 rshift
  dup R-DTPMOD = if drop 3 S-POBJ m@ ti@ 32 rshift else
  dup R-DTPOFF = if drop p-sval 4 S-RIDX m@ x@ + else
  dup R-TPOFF = if drop p-sval 4 S-RIDX m@ x@ + 0 S-POBJ m@ ti@ 32 rshift + S-TLS-BASE m@ + S-TCB-BASE m@ - else
    dup R-64 = if
      drop 4 S-POBJ m@ oi@ 5 S-POBJ m@ oi@ - p-sval + 4 S-RIDX m@ x@ +
    else
      drop 4 S-POBJ m@ oi@ 5 S-POBJ m@ oi@ - p-sval +
      S-XFER-MODE m@ 1 = if 4 S-RIDX m@ x@ + then
    then
  then then then ;
: sym-index 32 rshift ;
: req-ver
  13 o@ dup 0 > negate S-VPRESENT m! S-LOW m@ - swap 2 * +
  dup S-CURRENT-OBJECT m@ swap o8@ swap 1 + S-CURRENT-OBJECT m@ swap o8@ 8 lshift +
  S-VPRESENT m@ * ;
: prov-ver
  13 S-POBJ m@ oi@ dup 0 > negate S-VPRESENT m! 5 S-POBJ m@ oi@ - swap 2 * +
  dup S-POBJ m@ swap o8@ swap 1 + S-POBJ m@ swap o8@ 8 lshift + S-VPRESENT m@ * ;
: rq64 S-LOW m@ - S-CURRENT-OBJECT m@ swap o64@ ;
: pv64 5 S-POBJ m@ oi@ - S-POBJ m@ swap o64@ ;
: adapters
  63 for i blob64 i dup 49 u< if A-BASE + else 49 - AR-BASE + then m! next ;
: av@ S-ADAPTER m@ 1 - A-SIZE * A-BASE + + m@ ;
: ar@ S-ADAPTER m@ 1 - 2 * AR-BASE + + m@ ;
: known-build?
  S-VMAL m!
  dup ph-filesz 36 u< if drop 0 else
    PH-OFFSET ph-u64 S-STAGE64 m!
    S-STAGE64 m@ u32 4 = S-STAGE64 m@ 4 + u32 20 = and
    S-STAGE64 m@ 8 + u32 3 = and S-STAGE64 m@ 12 + u32 5590599 = and
    S-STAGE64 m@ 16 + u64 S-VMAL m@ A-SIZE * A-BASE + m@ = and
    S-STAGE64 m@ 24 + u64 S-VMAL m@ A-SIZE * A-BASE + 1 + m@ = and
    S-STAGE64 m@ 32 + u32 S-VMAL m@ A-SIZE * A-BASE + 2 + m@ = and
  then ;
: cpu!
  1 swap 3 av@ + 5 1 oi@ - o64! ;
: ld!
  1 swap 5 av@ + 5 1 oi@ - o64! ;
: cpu-setup
  S-ADAPTER m@ if 3 av@ if
    0 0 cpuid S-VMAL m! S-VAUX m! S-VPTR m! S-VHASH m!
    S-VHASH m@ 32 lshift 1 + 0 cpu!
    1 0 cpuid S-VMAL m! S-VAUX m! S-VPTR m! S-VHASH m!
    S-VPTR m@ 32 lshift S-VHASH m@ + 20 cpu!
    S-VMAL m@ 32 lshift S-VAUX m@ + 28 cpu!
    7 0 cpuid S-VMAL m! S-VAUX m! S-VPTR m! S-VHASH m!
    S-VPTR m@ 32 lshift S-VHASH m@ + 52 cpu!
    S-VMAL m@ 32 lshift S-VAUX m@ + 60 cpu!
  then then ;
: runtime-setup
  S-TCB-BASE m@ 512 + 0 ld!
  4 0 oi@ 5 0 oi@ - stage64 pbase S-TCB-BASE m@ 512 + 8 oscopy drop
  S-ADAPTER m@ 3 = if
    4 1 oi@ 5 1 oi@ - dup 126848 + 1 5 av@ 4016 + 5 1 oi@ - o64!
    126864 + 1 5 av@ 4024 + 5 1 oi@ - o64!
  then ;
: vm-step
  S-VCOUNT m@ 0 > S-VMAL m@ 0= and if
    S-VPTR m@ pv64 32 rshift V-MASK and S-VINDEX m@ =
    S-VPTR m@ 8 + pv64 R-MASK and S-VHASH m@ = and if
      1 S-VMAL m!
    else
      S-VPTR m@ 16 + pv64 R-MASK and S-VPTR m@ + S-VPTR m!
    then
    S-VCOUNT m@ 1 - S-VCOUNT m!
  then ;
: vm-steps8 vm-step vm-step vm-step vm-step vm-step vm-step vm-step vm-step ;
: vi-step
  S-VCOUNT m@ 0 > S-VMAL m@ 0= and if
    S-VPTR m@ pv64 32 rshift V-MASK and S-VINDEX m@ = if
      S-VPTR m@ 8 + pv64 R-MASK and S-VHASH m! 1 S-VMAL m!
    else
      S-VPTR m@ 16 + pv64 R-MASK and S-VPTR m@ + S-VPTR m!
    then
    S-VCOUNT m@ 1 - S-VCOUNT m!
  then ;
: vi-steps8 vi-step vi-step vi-step vi-step vi-step vi-step vi-step vi-step ;
: version-match?
  2 S-RIDX m@ x@ R-MASK and req-ver V-MASK and
  dup 1 u> if
    S-VINDEX m! S-POBJ m@ S-VAUX m!
    5 S-RIDX m@ x@ 32 rshift S-VHASH m!
    S-VHASH m@ 0= if
      S-CURRENT-OBJECT m@ S-POBJ m! S-CURRENT-OBJECT m@ V-BASE + m@ S-VPTR m!
      S-CURRENT-OBJECT m@ VN-BASE + m@ 48 min S-VCOUNT m! 0 S-VMAL m!
      vi-steps8 vi-steps8 vi-steps8 vi-steps8 vi-steps8 vi-steps8
    then
    S-VAUX m@ S-POBJ m!
    S-CUR-SYM m@ prov-ver V-MASK and S-VINDEX m!
    S-POBJ m@ V-BASE + m@ S-VPTR m! S-POBJ m@ VN-BASE + m@ 48 min S-VCOUNT m!
    0 S-VMAL m!
    vm-steps8 vm-steps8 vm-steps8 vm-steps8 vm-steps8 vm-steps8
    S-VMAL m@
  else drop -1 then ;
: plan-load
  dup ph-memsz P-MEMSZ plan-v!
  dup ph-vaddr S-LOW m@ - P-VADDR plan-v!
  dup ph-prot P-PROT plan-v!
  dup ph-x 0 > if
    S-PLAN-XPROT inc@
    S-VHASH m@ -1 = if
      dup ph-vaddr S-LOW m@ - page-down S-VHASH m!
      dup ph-vaddr S-LOW m@ - over ph-memsz + page-up S-VPTR m!
    then
  then
  S-PLAN-PROT inc@
  drop S-PLAN-MAPS inc@ ;
: dyn-base S-DYNOFF m@ swap 16 * + ;
: dyn-tag dyn-base u64 ;
: dyn-val dyn-base 8 + u64 ;
: dyn!
  S-VHASH m! S-VAUX m!
  dup dyn-tag S-VAUX m@ = if dyn-val S-VHASH m@ m! else drop then ;
: plan-needed
  need-can? if
    2 N-STATE need-v!
    S-CURRENT-OBJECT m@ N-REQUESTER need-v!
    dyn-val dup N-NAME need-v!
    need-img N-ADDRESS need-v!
    S-PNREC inc@
  else
    drop
  then ;
: img-off S-LOW m@ - ;
: rela-base S-RELA m@ img-off swap 24 * + ;
: rela-off S-CURRENT-OBJECT m@ swap rela-base o64@ ;
: rela-info S-CURRENT-OBJECT m@ swap rela-base 8 + o64@ ;
: rela-addend S-CURRENT-OBJECT m@ swap rela-base 16 + o64@ ;
: jmprela-base S-JMPREL m@ img-off swap 24 * + ;
: jmprela-off S-CURRENT-OBJECT m@ swap jmprela-base o64@ ;
: jmprela-info S-CURRENT-OBJECT m@ swap jmprela-base 8 + o64@ ;
: jmprela-addend S-CURRENT-OBJECT m@ swap jmprela-base 16 + o64@ ;
: relr-word S-REL m@ img-off swap 8 * + S-CURRENT-OBJECT m@ swap o64@ ;
: apply-relr
  S-REQ-SYM m!
  S-CURRENT-OBJECT m@ S-REQ-SYM m@ img-off o64@ 4 o@ +
  S-CURRENT-OBJECT m@ S-REQ-SYM m@ img-off o64!
  S-RELATIVE inc@ S-REL-APPLIED inc@ ;
: r-type R-MASK and ;
: symbolic?
  dup R-64 = swap dup R-GLOB = swap dup R-JUMP = swap dup R-DTPMOD =
  swap dup R-DTPOFF = swap R-TPOFF = or or or or or ;
: native-reloc? S-XFER-MODE m@ 1 = negate S-CURRENT-OBJECT m@ 0 > negate * 0= negate S-XFER-MODE m@ 3 = negate 0= negate * ;
: relro-now? S-XFER-MODE m@ 1 = negate S-INTERP m@ 0 > negate * 0= negate S-XFER-MODE m@ 3 = negate 0= negate * ;
: finish-protect?
  S-LINK-PHASE m@ 2 =
  S-LINK-PHASE m@ 1 = S-XFER-MODE m@ 2 = S-ADAPTER m@ 0 > and 0= and or ;
: finish-relro?
  S-LINK-PHASE m@ 2 =
  S-LINK-PHASE m@ native-reloc? * relro-now? *
  S-XFER-MODE m@ 2 = S-ADAPTER m@ 0 > and 0= negate * 0 > or ;
: sym-nameoff sym-index S-SYMENT m@ * S-SYMTAB m@ + img-off S-CURRENT-OBJECT m@ swap o64@ R-MASK and ;
: plan-rela-record
  reloc-can? if
    dup rela-info r-type S-PXREC m@ r!
    dup rela-info sym-index 2 reloc-v!
    dup rela-off 3 reloc-v!
    dup rela-addend 4 reloc-v!
    rela-info sym-nameoff 5 reloc-v!
    S-PXREC inc@
  else
    drop
  then ;
: plan-jmprel-rec
  reloc-can? if
    dup jmprela-info sym-index 2 reloc-v!
    dup jmprela-off 3 reloc-v!
    dup jmprela-addend 4 reloc-v!
    jmprela-info sym-nameoff 5 reloc-v!
    S-PXREC inc@
  else
    drop
  then ;
: walk-rela
  S-RELASZ m@ 24 u/ native-reloc? * for
    S-RELA-TOTAL inc@
    i rela-info r-type
    dup R-REL = if
      S-RELATIVE inc@
      i rela-addend 4 o@ + S-CURRENT-OBJECT m@ i rela-off img-off o64!
      S-REL-APPLIED inc@
    else
      dup R-DTPOFF = over R-TPOFF = or if
        S-LINK-PHASE m@ 1 = if
          i rela-info sym-index S-SYMENT m@ * S-SYMTAB m@ img-off + 8 +
          S-CURRENT-OBJECT m@ swap o64@ i rela-addend +
          over R-TPOFF = if 0 S-CURRENT-OBJECT m@ ti@ 32 rshift + S-TLS-BASE m@ + S-TCB-BASE m@ - then
          S-CURRENT-OBJECT m@ i rela-off img-off o64!
        then
      else dup R-DTPMOD = i rela-info sym-index 0= and if
        S-LINK-PHASE m@ 1 = if
          3 S-CURRENT-OBJECT m@ ti@ 32 rshift
          S-CURRENT-OBJECT m@ i rela-off img-off o64!
        then
      else dup symbolic? if
        S-SYMBOLIC inc@
        i plan-rela-record
        dup R-JUMP = if S-JUMP-SLOT inc@ then
      else
        dup R-IREL = if
          S-XFER-MODE m@ 2 = S-LINK-PHASE m@ 1 = and if
            S-RCALL m@ RCV-MAX u< if
              S-CURRENT-OBJECT m@ 0 rcv!
              i rela-addend img-off 1 rcv! i rela-off img-off 2 rcv! S-RCALL inc@
            else S-REQUIRED inc@ S-NATIVE-PENDING inc@ then
          else
            S-REQUIRED inc@
            S-IREL-COUNT m@ 0= S-CURRENT-OBJECT m@ 12 u< and if
              i rela-addend 32 lshift i rela-off + S-CURRENT-OBJECT m@ I-BASE + m!
            then
          then
          S-IREL-COUNT inc@
        else S-UNSUPPORTED inc@ then
      then then then
    then
    drop
  next ;
: walk-jmprela
  S-PLTREL m@ 7 = if
    S-PLTRELSZ m@ 24 u/ native-reloc? * for
      S-JMPREL-TOTAL inc@
      i jmprela-info r-type
      dup symbolic? if
        S-SYMBOLIC inc@
        i plan-jmprel-rec
        dup R-JUMP = if S-JUMP-SLOT inc@ then
      else
        dup R-IREL = if
          S-XFER-MODE m@ 2 = S-LINK-PHASE m@ 1 = and if
            S-RCALL m@ RCV-MAX u< if
              S-CURRENT-OBJECT m@ 0 rcv!
              i jmprela-addend img-off 1 rcv! i jmprela-off img-off 2 rcv! S-RCALL inc@
            else S-REQUIRED inc@ S-NATIVE-PENDING inc@ then
          else S-UNSUPPORTED inc@ then
          S-IREL-COUNT inc@
        else S-UNSUPPORTED inc@ then
      then
      drop
    next
  then ;
: walk-relr
  S-RELSZ m@ 8 u/ 64 * native-reloc? * for
    i 64 u/ T-Q m! i dup 64 u/ 64 * - T-B m!
    T-B m@ 0= if
      T-Q m@ relr-word dup 1 and 0= if
        dup 8 + S-RELR-NEXT m! apply-relr
      else drop then
    then
    T-B m@ 0 > T-Q m@ relr-word 1 and 1 = and if
      T-Q m@ relr-word T-B m@ rshift 1 and 1 = if
        S-RELR-NEXT m@ T-B m@ 1 - 8 * + apply-relr
      then
    then
    T-B m@ 63 = T-Q m@ relr-word 1 and 1 = and if
      S-RELR-NEXT m@ 504 + S-RELR-NEXT m!
    then
  next ;
: hash-names
  S-PXREC m@ SYM-NAME-MAX * for
    i SYM-NAME-MAX u/ T-Q m!
    i dup SYM-NAME-MAX u/ SYM-NAME-MAX * - T-B m!
    T-B m@ 0= if 5381 T-Q m@ h! 1 T-Q m@ a! then
    T-Q m@ a@ 1 = if
      S-CURRENT-OBJECT m@ S-STRTAB m@ img-off
      5 T-Q m@ x@ + T-B m@ + o8@
      dup 0 > if T-Q m@ h@ 33 * + T-Q m@ h! else drop 0 T-Q m@ a! then
    then
  next
  S-PXREC m@ 256 * S-LINK-PHASE m@ * for
    i 256 u/ S-RIDX m! i dup 256 u/ 256 * - dup 16 u/ T-Q m! dup 16 umod T-B m!
    0= if
      T-Q m@ 0= if 0 S-VHASH m! then
      2 S-RIDX m@ x@ R-MASK and req-ver V-MASK and S-VINDEX m!
      14 o@ R-MASK and S-VPTR m! 14 o@ 32 rshift 16 min S-VCOUNT m!
    then
    T-B m@ 0= T-Q m@ S-VCOUNT m@ u< and if
      S-VPTR m@ 8 + rq64 R-MASK and S-VPTR m@ + S-VAUX m!
      S-VPTR m@ rq64 16 rshift 65535 and 16 min S-VPRESENT m!
    then
    T-Q m@ S-VCOUNT m@ u< T-B m@ S-VPRESENT m@ u< and
    S-VHASH m@ 0= and if
      S-VAUX m@ rq64 dup 48 rshift V-MASK and S-VINDEX m@ = if R-MASK and S-VHASH m! else drop then
      S-VHASH m@ 0= T-B m@ 1 + S-VPRESENT m@ u< and if
        S-VAUX m@ 8 + rq64 32 rshift S-VAUX m@ + S-VAUX m!
      then
    then
    T-B m@ 15 = T-Q m@ 1 + S-VCOUNT m@ u< and S-VHASH m@ 0= and if
      S-VPTR m@ 8 + rq64 32 rshift S-VPTR m@ + S-VPTR m!
    then
    T-Q m@ 15 = T-B m@ 15 = and if
      S-VHASH m@ 32 lshift 5 S-RIDX m@ x@ R-MASK and + 5 S-RIDX m@ xi!
    then
  next
  S-QUEUE-TAIL m@ P-MAX min S-PROVIDERS m!
  S-PXREC m@ S-PROVIDERS m@ * C-MAX * S-LINK-PHASE m@ * for
    i C-MAX u/ T-Q m!
    i dup C-MAX u/ C-MAX * - T-B m!
    T-Q m@ S-PROVIDERS m@ u/ S-RIDX m!
    T-Q m@ dup S-PROVIDERS m@ u/ S-PROVIDERS m@ * - S-POBJ m!
    T-B m@ 0= if 0 S-CUR-SYM m! then
    12 S-POBJ m@ oi@ 0 > if
      T-B m@ 0= if
        S-RIDX m@ h@ R-MASK and S-POBJ m@ p-bucket
        S-CUR-SYM m! S-GNU-CAND metric+ S-CUR-SYM m@ 0 > if S-GNU-NONEMPTY metric+ then
      then
      S-CUR-SYM m@ 0 > if
        S-RIDX m@ h@ R-MASK and S-POBJ m@ p-bucket drop
        S-CUR-SYM m@ p-chain-at
        S-CHAIN-VISIT metric+
        dup S-RIDX m@ h@ R-MASK and 1 or swap 1 or = if
          S-CHAIN-MATCH metric+ T-B m@ 0= if S-GNU-HMATCH metric+ then
        S-CURRENT-OBJECT m@ S-STRTAB m@ img-off 5 S-RIDX m@ x@ R-MASK and +
        S-POBJ m@
        9 S-POBJ m@ oi@ 5 S-POBJ m@ oi@ -
        10 S-POBJ m@ oi@ 5 S-POBJ m@ oi@ -
        S-CUR-SYM m@ 15 S-POBJ m@ oi@ * +
        S-POBJ m@ swap o64@ R-MASK and
        + streq S-RIDX m@ z@ 0= and
        version-match? and if
          S-NAME-MATCH metric+ S-RESOLVED metric+ 1 S-RIDX m@ z!
          p-type 10 = S-XFER-MODE m@ 2 = and if
            2 S-RIDX m@ z!
            S-POBJ m@ 32 lshift 2 S-RIDX m@ x@ R-MASK and + 2 S-RIDX m@ xi!
            S-CUR-SYM m@ 32 lshift 5 S-RIDX m@ x@ R-MASK and + 5 S-RIDX m@ xi!
          else
            S-RIDX m@ reloc-value
            S-CURRENT-OBJECT m@ 3 S-RIDX m@ x@ R-MASK and img-off o64!
          then
        then
        then
        dup 1 and 1 = if drop 0 S-CUR-SYM m! else drop S-CUR-SYM m@ 1 + S-CUR-SYM m! then
      then
    then
  next ;
: low-update
  S-LOW m@ -1 = if dup S-LOW m! else dup S-LOW m@ u< if dup S-LOW m! then then drop ;
: high-update
  dup S-HIGH m@ u> if S-HIGH m! else drop then ;
: plan-finalize
  S-NEEDED m@ S-PLAN-DEPS m!
  E-ENTRY u64 S-PLAN-ENTRY m!
  S-INTERP m@ 0 > if 2 S-PLAN-TARGET m! else 1 S-PLAN-TARGET m! then
  S-RELA-TOTAL m@ S-JMPREL-TOTAL m@ + S-PLAN-RELOC m!
  S-REL-APPLIED m@ S-PLAN-REL-WR m!
  S-SYMBOLIC m@ S-PLAN-SYM m!
  S-BSS m@ S-PLAN-BSS m!
  S-SPAN m@ S-PLAN-SPAN m!
  1 S-PLAN-DONE m! ;

zero-stats
zero-relocs
zero-plan
elen 0= S-CURRENT-SOURCE m@ 0= and if
  pbase MAIN-PATH + S-MAIN-PATH-LEN m@ 0 16777216 osread
  dup 0 > if drop 0 esource else drop 2013 m@ drop then
then
S-CURRENT-SOURCE m@ esource
S-XFER-MODE m@ 5 = if
  E-PHNUM u16 for i ph-interp? if 2013 m@ drop then next
  3 S-XFER-MODE m!
then
S-XFER-MODE m@ 4 = if
  3 S-XFER-MODE m!
  E-PHNUM u16 for i ph-interp? if 2 S-XFER-MODE m! then next
then
S-CURRENT-OBJECT m@ 0= S-LINK-PHASE m@ 0= and if adapters 0 S-ADAPTER m! -1 S-LIBC m! then

E-PHNUM u16 for
  i ph-load? if S-LOADS inc@ i ph-bss S-BSS add@ then
  i ph-tls? S-LINK-PHASE m@ 0= and if
    i tls-ok? if
      i ph-vaddr 0 tls! i ph-filesz 1 tls! i ph-memsz 2 tls! i PH-ALIGN ph-u64 3 tls!
    else 2013 m@ drop then
  then
  i ph-interp? if S-INTERP inc@ then
  i ph-interp? if
    i PH-OFFSET ph-u64 10 o!
    i ph-filesz 1 - 9 o!
  then
  i ph-dynamic? if
    S-DYNAMIC inc@
    i PH-OFFSET ph-u64 S-DYNOFF m!
    i ph-filesz S-DYNSZ m!
    i ph-vaddr S-DYNVA m!
  then
  i ph-note? S-CURRENT-OBJECT m@ 1 = and S-LINK-PHASE m@ 0= and if
    i 0 known-build? if 1 S-ADAPTER m! then
    i 1 known-build? if 2 S-ADAPTER m! then
    i 2 known-build? if 3 S-ADAPTER m! then
    i 3 known-build? if 4 S-ADAPTER m! then
    i 4 known-build? if 5 S-ADAPTER m! then
    i 5 known-build? if 6 S-ADAPTER m! then
    i 6 known-build? if 7 S-ADAPTER m! then
  then
next

S-LINK-PHASE m@ 0= if
S-CURRENT-OBJECT m@ 0= 9 o@ 12 u> and if
  10 o@ 8 + u8 109 = 10 o@ 9 + u8 117 = and
  10 o@ 10 + u8 115 = and 10 o@ 11 + u8 108 = and if 1 S-MUSL m! then
then
9 o@ for
  10 o@ i + u8 i p8!
next
9 o@ 0 > if
  pbase 9 o@ 1 16777216 osread
  dup 0 > if dup osclose drop drop else drop then
then
then

E-PHNUM u16 for
  i ph-load? if
    i ph-w 0 > i ph-x 0 > and if 2013 m@ drop then
    i ph-vaddr low-update i ph-end high-update
  then
next

S-HIGH m@ S-LOW m@ - S-SPAN m!

S-LINK-PHASE m@ 2 = 0= if
  1 0 o! ebase 2 o! elen 3 o!
  S-LOW m@ 5 o! S-HIGH m@ 6 o!
  E-ENTRY u64 7 o! S-SPAN m@ page-up 8 o!
  S-LOW m@ S-SPAN m@ page-up 3 E-TYPE u16 2 = negate OM-FIXED * OM-ANON +
  osmap 4 o!
then

-1 S-VHASH m! 0 S-VPTR m!
E-PHNUM u16 for
  i ph-load? if i plan-load then
next
S-VHASH m@ -1 = invert if
  E-ENTRY u64 R-MASK and S-VHASH m@ 32 lshift + 7 o!
  S-HIGH m@ R-MASK and S-VPTR m@ S-VHASH m@ - 32 lshift + 6 o!
then

S-LINK-PHASE m@ 2 = 0= if
  E-PHNUM u16 for
    i ph-load? if
      i PH-OFFSET ph-u64
      i ph-vaddr S-LOW m@ -
      i ph-filesz
      S-CURRENT-OBJECT m@
      ecopy
      S-COPIED inc@
    then
  next
then

S-DYNSZ m@ 16 u/ for
  i dyn-tag DT-NEEDED = if S-NEEDED inc@ i plan-needed then
  i DT-HASH S-HASH dyn!
  i DT-GNU-HASH S-GNU-HASH dyn!
  i DT-RELA S-RELA dyn! i DT-RELASZ S-RELASZ dyn!
  i DT-RELR S-REL dyn! i DT-RELRSZ S-RELSZ dyn!
  i DT-JMPREL S-JMPREL dyn! i DT-PLTRELSZ S-PLTRELSZ dyn! i DT-PLTREL S-PLTREL dyn!
  i DT-STRTAB S-STRTAB dyn! i DT-STRSZ S-STRSZ dyn!
  i DT-SYMTAB S-SYMTAB dyn! i DT-SYMENT S-SYMENT dyn!
  i DT-VERSYM S-VERSYM dyn!
  i DT-VERNEED S-VERNEED dyn! i DT-VERNEEDNUM S-VERNEEDNUM dyn!
  i dyn-tag DT-VERDEF = if i dyn-val v! then
  i dyn-tag DT-VERDEFNUM = if i dyn-val vn! then
  i DT-RUNPATH S-RUNPATH dyn!
  i dyn-tag DT-RPATH = S-RUNPATH m@ 0= and if i dyn-val S-RUNPATH m! then
  i dyn-tag DT-INIT = if i dyn-val 0 init! then
  i dyn-tag DT-INIT-ARRAY = if i dyn-val 1 init! then
  i dyn-tag DT-INIT-ARRAYSZ = if i dyn-val 2 init! then
next
S-ADAPTER m@ 0 > S-CURRENT-OBJECT m@ 1 u> and if
  S-CURRENT-OBJECT m@ VN-BASE + m@ 4 av@ = if S-CURRENT-OBJECT m@ S-LIBC m! then
then

S-STRTAB m@ 9 o!
S-SYMTAB m@ 10 o!
S-HASH m@ 11 o!
S-GNU-HASH m@ 12 o!
S-VERSYM m@ 13 o!
S-VERNEEDNUM m@ 32 lshift S-VERNEED m@ + 14 o!
S-SYMENT m@ 15 o!

S-PNREC m@ 0 > if
  S-PNREC m@ dup * for
    i S-PNREC m@ u/ T-Q m!
    i dup S-PNREC m@ u/ S-PNREC m@ * - T-B m!
    T-B m@ T-Q m@ u< if
      N-REQUESTER T-Q m@ n@ N-REQUESTER T-B m@ n@ =
      N-NAME T-Q m@ n@ N-NAME T-B m@ n@ = and if 0 N-STATE T-Q m@ n-cell m! then
    then
  next
then
0 S-NAME-UNIQUE m!
S-PNREC m@ for N-STATE i n@ 0 > if S-NAME-UNIQUE inc@ then next

S-PNREC m@ Q-MAX min S-NAME-COUNT m!
S-NAME-COUNT m@ Q-NAME-MAX * for
  i Q-NAME-MAX u/ T-Q m!
  i dup Q-NAME-MAX u/ Q-NAME-MAX * - T-B m!
  T-B m@ 0= if S-CURRENT-OBJECT m@ 0 T-Q m@ q! 0 1 T-Q m@ q! then
  N-STATE T-Q m@ n@ 0 > if
    S-CURRENT-OBJECT m@ S-STRTAB m@ S-LOW m@ - N-NAME T-Q m@ n@ + T-B m@ + o8@
    dup 0 > T-B m@ 1 T-Q m@ q@ = and if
      dup 2 T-B m@ + T-Q m@ q!
      1 T-Q m@ q@ 1 + 1 T-Q m@ q!
      drop
    else drop then
  then
next

S-LINK-PHASE m@ 0= if
system-dir
S-CURRENT-OBJECT m@ 0= S-RUNPATH m@ 0 > and S-XFER-MODE m@ 2 = or
S-MAIN-PATH-LEN m@ 0 > and if
  0 S-DIR-LEN m! 1 S-ORIGIN-ACTIVE m!
  S-MAIN-PATH-LEN m@ for
    MAIN-PATH i + p8@ dup i p8!
    47 = if i 1 + S-DIR-LEN m! then
  next
then
Q-MAX 256 * for
  i 256 u/ T-Q m! i dup 256 u/ 256 * - T-B m!
  T-B m@ S-DIR-LEN m@ u< if
    T-B m@ p8@ T-Q m@ 256 * T-B m@ + p8!
  else
    T-B m@ S-DIR-LEN m@ - 1 T-Q m@ q@ u< if
      2 T-B m@ S-DIR-LEN m@ - + T-Q m@ q@
      T-Q m@ 256 * T-B m@ + p8!
    then
  then
next
0 S-QUEUE-TAIL m!
48 for
  1 i oi@ 0 > if i 1 + S-QUEUE-TAIL m@ max S-QUEUE-TAIL m! then
next
S-NAME-COUNT m@ Q-MAX min S-XFER-MODE m@ 1 = negate 0= negate * for
  pbase i 256 * + S-DIR-LEN m@ 1 i q@ + S-QUEUE-TAIL m@ 16777216 osread
  dup 0 > if
    dup 32 rshift 1 - edge!
    dup 32 rshift 1 - S-QUEUE-TAIL m@ = if S-QUEUE-TAIL inc@ then
    0 1 i q! osclose drop
  else drop then
next
S-ORIGIN-ACTIVE m@ if
  system-dir
  Q-MAX 256 * for
    i 256 u/ T-Q m! i dup 256 u/ 256 * - T-B m!
    T-B m@ S-DIR-LEN m@ u< if T-B m@ p8@ T-Q m@ 256 * T-B m@ + p8!
    else T-B m@ S-DIR-LEN m@ - 1 T-Q m@ q@ u< if
      2 T-B m@ S-DIR-LEN m@ - + T-Q m@ q@ T-Q m@ 256 * T-B m@ + p8!
    then then
  next
  S-NAME-COUNT m@ Q-MAX min S-XFER-MODE m@ 1 = negate 0= negate * for
    pbase i 256 * + S-DIR-LEN m@ 1 i q@ + S-QUEUE-TAIL m@ 16777216 osread
    dup 0 > if
      dup 32 rshift 1 - edge!
      dup 32 rshift 1 - S-QUEUE-TAIL m@ = if S-QUEUE-TAIL inc@ then
      osclose drop
    else drop then
  next
then
then

S-LINK-PHASE m@ 2 = 0= if
S-LINK-PHASE m@ 1 = S-CURRENT-OBJECT m@ 0= and if
  S-XFER-MODE m@ 2 = S-MUSL m@ 0= and S-INTERP m@ 0 > and S-ADAPTER m@ 0= and if 2013 m@ drop then
  0 S-NATIVE-CALLS m! 0 S-NATIVE-PENDING m! 0 S-NATIVE-RESULTS m!
  0 S-IFUNC-CALLS m! 0 S-IFUNC-RESULT m! tls-layout
  0 S-CONSTRUCTORS m!
then
S-LINK-PHASE m@ 1 = S-ADAPTER m@ 0 > and S-XFER-MODE m@ 2 = and
S-CURRENT-OBJECT m@ 2 u< and if cpu-setup runtime-setup then
S-CURRENT-OBJECT m@ S-LIBC m@ = if
  4 1 oi@ 5 1 oi@ - 0 ar@ +
  S-CURRENT-OBJECT m@ 1 ar@ S-LOW m@ - o64!
then
0 S-RCALL m!
walk-relr
0 S-IREL-COUNT m!
walk-rela
walk-jmprela
hash-names
S-RCALL m@ for
  0 i rcv-cell m@ 1 i rcv-cell m@ ncall dup 0 > if S-NATIVE-RESULTS metric+ then
  0 i rcv-cell m@ 2 i rcv-cell m@ o64! S-NATIVE-CALLS metric+
next
S-PXREC m@ S-LINK-PHASE m@ * S-XFER-MODE m@ 2 = negate * for
  i z@ 2 = if
    i S-RIDX m! 2 i x@ 32 rshift S-POBJ m! 5 i x@ 32 rshift S-CUR-SYM m!
    S-POBJ m@ p-sval 5 S-POBJ m@ oi@ - ncall dup S-IFUNC-RESULT m! S-IFUNC-CALLS inc@
    dup 0 > if S-NATIVE-RESULTS metric+ then 4 i x@ +
    S-CURRENT-OBJECT m@ 3 i x@ R-MASK and img-off o64!
    1 i z! S-NATIVE-CALLS metric+
  then
next
S-REL-APPLIED m@ 32 lshift S-RESOLVED m@ + S-CURRENT-OBJECT m@ Y-BASE + m!
0 S-REQ-SYM m!
S-PXREC m@ for
  i z@ 0= if
    S-CURRENT-OBJECT m@ S-SYMTAB m@ img-off
    2 i x@ R-MASK and S-SYMENT m@ * + 4 + o8@ 4 rshift 2 =
    if
      S-WEAK-MISSING metric+
    else
      S-REQUIRED m@ 0= if 2 i x@ R-MASK and S-REQ-SYM m! then
      S-REQUIRED inc@
    then
  then
next
S-XFER-MODE m@ 2 = S-REQUIRED m@ 0 > and if S-REQUIRED m@ S-NATIVE-PENDING add@ then
S-REQ-SYM m@ 32 lshift S-REQUIRED m@ + S-CURRENT-OBJECT m@ W-BASE + m!
then
plan-finalize

S-PLAN-MAPS m@ finish-protect? negate * for
  O-MAP-BASE o@ P-VADDR i p@ page-down +
  P-VADDR i p@ P-MEMSZ i p@ + page-up P-VADDR i p@ page-down -
  P-PROT i p@ osprot 0= if S-PROTECTED metric+ then
next
E-PHNUM u16 finish-relro? negate * S-REQUIRED m@ 0= negate * for
  i ph-relro? if
    4 o@ i ph-vaddr S-LOW m@ - page-down +
    i ph-vaddr S-LOW m@ - i ph-memsz + page-up
    i ph-vaddr S-LOW m@ - page-down -
    1 osprot 0= if S-RELRO-PROT metric+ then
  then
next

0 S-QUEUE-TAIL m!
48 for
  1 i oi@ 0 > if i 1 + S-QUEUE-TAIL m@ max S-QUEUE-TAIL m! then
next
S-XFER-MODE m@ 2 = S-ADAPTER m@ 0 > and S-LINK-PHASE m@ 1 = and
S-CURRENT-OBJECT m@ 1 + S-QUEUE-TAIL m@ u< 0= and if
  0 S-VHASH m! 0 S-VPTR m!
  100 for
    i 10 umod S-VINDEX m!
    S-VINDEX m@ 0 > S-VINDEX m@ S-QUEUE-TAIL m@ u< and
    1 S-VINDEX m@ lshift S-VHASH m@ and 0= and if
      2 S-VINDEX m@ ii@ 32 rshift S-VHASH m@ invert and 0= if
        S-VINDEX m@ S-VPTR m@ RCV-BASE + m!
        1 S-VINDEX m@ lshift S-VHASH m@ or S-VHASH m! S-VPTR inc@
      then
    then
  next
  S-VPTR m@ S-QUEUE-TAIL m@ 1 - = S-NATIVE-PENDING m@ 0= and if
    0 S-VPTR m@ RCV-BASE + m! S-VPTR inc@
    S-VPTR m@ for
      i RCV-BASE + m@ S-VINDEX m! 0 S-VINDEX m@ ii@ dup 0 > if
        5 S-VINDEX m@ oi@ - S-VINDEX m@ swap ncall drop S-CONSTRUCTORS metric+
      else drop then
    next
    S-VPTR m@ 16 * for
      i 16 u/ RCV-BASE + m@ S-VINDEX m! i 16 umod S-VCOUNT m!
      S-VCOUNT m@ 8 * 2 S-VINDEX m@ ii@ R-MASK and u< if
        1 S-VINDEX m@ ii@ 5 S-VINDEX m@ oi@ - S-VCOUNT m@ 8 * +
        S-VINDEX m@ swap o64@ dup 0 > if
          4 S-VINDEX m@ oi@ - S-VINDEX m@ swap ncall drop S-CONSTRUCTORS metric+
        else drop then
      then
    next
  else S-NATIVE-PENDING inc@ then
then
S-CURRENT-OBJECT m@ 1 + dup S-QUEUE-TAIL m@ u< if
  dup S-CURRENT-SOURCE m! S-CURRENT-OBJECT m!
else
  drop
  S-LINK-PHASE m@ 0= if
    1 S-LINK-PHASE m! 0 S-CURRENT-SOURCE m! 0 S-CURRENT-OBJECT m!
  else
    S-LINK-PHASE m@ 1 = S-XFER-MODE m@ 2 = and S-ADAPTER m@ 0 > and
    S-NATIVE-PENDING m@ 0= and if
      2 S-LINK-PHASE m! 0 S-CURRENT-SOURCE m! 0 S-CURRENT-OBJECT m!
    else
      -1 S-CURRENT-SOURCE m! -1 S-CURRENT-OBJECT m!
    then
  then
then
