: e.magic 0 u32 ; : e.class 4 u8 ; : e.data 5 u8 ;
: e.type 16 u16 ; : e.machine 18 u16 ; : e.entry 24 u64 ;
: e.phoff 32 u64 ; : e.phentsz 54 u16 ; : e.phnum 56 u16 ;
: ph-base e.phoff swap e.phentsz * + ;
: ph.type ph-base u32 ; : ph.flags ph-base 4 + u32 ;
: ph.offset ph-base 8 + u64 ; : ph.vaddr ph-base 16 + u64 ;
: ph.filesz ph-base 32 + u64 ; : ph.memsz ph-base 40 + u64 ;
: ph.align ph-base 48 + u64 ;

e.magic . cr
e.class . cr
e.data . cr
e.type . cr
e.machine . cr
e.entry . cr
e.phoff . cr
e.phentsz . cr
e.phnum . cr
0 ph.type . cr
0 ph.flags . cr
0 ph.offset . cr
0 ph.vaddr . cr
0 ph.filesz . cr
0 ph.memsz . cr
0 ph.align . cr
1 ph.type . cr
1 ph.flags . cr
1 ph.offset . cr
1 ph.vaddr . cr
1 ph.filesz . cr
1 ph.memsz . cr
1 ph.align . cr
2 ph.type . cr
2 ph.flags . cr
2 ph.offset . cr
2 ph.vaddr . cr
2 ph.filesz . cr
2 ph.memsz . cr
2 ph.align . cr
3 ph.type . cr
3 ph.flags . cr
3 ph.offset . cr
3 ph.vaddr . cr
3 ph.filesz . cr
3 ph.memsz . cr
3 ph.align . cr
