#ifndef FORTH_WORKSPACE_H
#define FORTH_WORKSPACE_H

#include <stdint.h>

#define WS_MAGIC_VALUE 0x465448504f435031ULL
#define WORKSPACE_SIZE 2097152
#define OUTPUT_SIZE 8192
#define MAX_TRANSFORM_ROUNDS 4
#define WS_FLAG_COMPILE_ONLY 2
#define WS_FLAG_CALLABLE 4
#define WS_FLAG_SYSCALL_SERVICES 8
#define DICT_ENTRY_SIZE 48
#define DICT_CONST 1
#define DICT_CALLABLE 3
#define DATA_BASE_OFF 768
#define DATA_CELLS 2013
#define IMAGE_BASE_OFF 16896
#define IMAGE_SIZE 458240
#define FORTH_SOURCE_SIZE_MAX 16777216
#define FORTH_OBJECT_MAP_MAX 16777216
#define ORIG_BASE_OFF 475136
#define ORIG_SIZE 202752
#define XFORM_BASE_OFF 677888
#define XFORM_SIZE 387072
#define TRACE_BASE_OFF 1064960
#define TRACE_SIZE 8192
#define SCRATCH_BASE_OFF 1073152
#define PATH_BUFFER_SIZE 4096
#define PATH_BUFFER_BASE_OFF (WORKSPACE_SIZE - PATH_BUFFER_SIZE)
#define SCRATCH_SIZE (PATH_BUFFER_BASE_OFF - SCRATCH_BASE_OFF)

_Static_assert(DATA_BASE_OFF + DATA_CELLS * sizeof(uint64_t) <= IMAGE_BASE_OFF,
               "data region overlaps image region");
_Static_assert(IMAGE_BASE_OFF + IMAGE_SIZE <= ORIG_BASE_OFF,
               "image region overlaps original-bytecode region");
_Static_assert(ORIG_BASE_OFF + ORIG_SIZE <= XFORM_BASE_OFF,
               "original-bytecode region overlaps transform region");
_Static_assert(XFORM_BASE_OFF + XFORM_SIZE <= TRACE_BASE_OFF,
               "transform region overlaps trace region");
_Static_assert(TRACE_BASE_OFF + TRACE_SIZE <= SCRATCH_BASE_OFF,
               "trace region overlaps scratch region");
_Static_assert(SCRATCH_BASE_OFF + SCRATCH_SIZE == PATH_BUFFER_BASE_OFF,
               "scratch region overlaps path buffer");
_Static_assert(PATH_BUFFER_BASE_OFF + PATH_BUFFER_SIZE == WORKSPACE_SIZE,
               "path buffer must end at workspace boundary");

#define FORTH_PLAN_MAPS 28
#define FORTH_PLAN_PROT 29
#define FORTH_PLAN_XPROT 30
#define FORTH_PLAN_DEPS 31
#define FORTH_PLAN_ENTRY 32
#define FORTH_PLAN_TARGET 33
#define FORTH_PLAN_RELOC 34
#define FORTH_PLAN_REL_WRITES 35
#define FORTH_PLAN_SYMBOLIC 36
#define FORTH_PLAN_BSS 37
#define FORTH_PLAN_SPAN 38
#define FORTH_PLAN_DONE 39
#define FORTH_PLAN_NEEDED_RECORDS 40
#define FORTH_PLAN_RELOC_RECORDS 41
#define FORTH_PLAN_HASH 42
#define FORTH_PLAN_GNU_HASH 43
#define FORTH_PLAN_STRSZ 44
#define FORTH_PLAN_SYMENT 45
#define FORTH_PLAN_VERSYM 46
#define FORTH_PLAN_VERNEED 47
#define FORTH_DYN_STRTAB 15
#define FORTH_DYN_SYMTAB 16
#define FORTH_DYN_RELA 8
#define FORTH_DYN_RELASZ 9
#define FORTH_DYN_JMPREL 12
#define FORTH_DYN_PLTRELSZ 13
#define FORTH_DYN_PLTREL 14
#define FORTH_IMAGE_LOW 17
#define FORTH_PLAN_RECORD_BASE 48
#define FORTH_PLAN_RECORD_SIZE 8
#define FORTH_NEEDED_RECORD_BASE 112
#define FORTH_NEEDED_RECORD_SIZE 4
#define FORTH_NEEDED_RECORD_MAX 15
#define FORTH_PLAN_VERNEEDNUM 175
#define FORTH_RELOC_RECORD_BASE 176
#define FORTH_RELOC_RECORD_SIZE 8
#define FORTH_RELOC_RECORD_MAX 10
#define FORTH_OBJECT_RECORD_BASE 256
#define FORTH_OBJECT_RECORD_SIZE 16
#define FORTH_OBJECT_RECORD_MAX 48
#define FORTH_CURRENT_SOURCE 1948
#define FORTH_CURRENT_OBJECT 1949
#define FORTH_QUEUE_TAIL 1790
#define FORTH_LINK_PHASE 1947
#define FORTH_GNU_CANDIDATES 1930
#define FORTH_GNU_NONEMPTY 1931
#define FORTH_GNU_HASH_MATCHES 1932
#define FORTH_GNU_CHAIN_VISITS 1933
#define FORTH_GNU_CHAIN_MATCHES 1934
#define FORTH_GNU_PREFIX_MATCHES 1939
#define FORTH_SYMBOLS_RESOLVED 1940
#define FORTH_SEGMENTS_PROTECTED 1941
#define FORTH_RELRO_PROTECTED 1942
#define FORTH_LOADER_PASS 1023
#define FORTH_OBJECT_RESOLVED_BASE 1822
#define FORTH_TRANSFER_MODE 1821
#define FORTH_OBJECT_REQUIRED_UNRESOLVED_BASE 1870
#define FORTH_OBJECT_IRELATIVE_BASE 1918
#define FORTH_OBJECT_VERDEF_BASE 1600
#define FORTH_OBJECT_VERDEFNUM_BASE 1648
#define FORTH_MAIN_PATH_LEN 1696
#define FORTH_ADAPTER_SELECTED 1692
#define FORTH_NATIVE_CALLS 1693
#define FORTH_NATIVE_PENDING 1694
#define FORTH_NATIVE_RESULTS 1691
#define FORTH_IFUNC_CALLS 1689
#define FORTH_IFUNC_RESULT 1690
#define FORTH_CONSTRUCTORS_CALLED 1688
#define FORTH_LIBC_OBJECT 1687
#define FORTH_ADAPTER_BASE 1950
#define FORTH_ADAPTER_SIZE 7
#define FORTH_MAIN_PATH_OFFSET 3840
#define FORTH_PATH_BUFFER_SIZE 4096
#define FORTH_TLS_RECORD_BASE 1710
#define FORTH_TLS_RECORD_SIZE 4
#define FORTH_INIT_RECORD_BASE 1758
#define FORTH_INIT_RECORD_MAX 10
#define FORTH_TLS_TOTAL 1704
#define FORTH_TLS_BASE 1705
#define FORTH_TCB_BASE 1707
#define FORTH_INIT_RECORD_SIZE 3

#define OP_LIT 1
#define OP_DUP 2
#define OP_DROP 3
#define OP_SWAP 4
#define OP_OVER 5
#define OP_ADD 6
#define OP_SUB 7
#define OP_MUL 8
#define OP_EQ 9
#define OP_LT 10
#define OP_GT 11
#define OP_DOT 12
#define OP_EMIT 13
#define OP_CR 14
#define OP_NEG 15
#define OP_ZEROEQ 16
#define OP_ONEPLUS 17
#define OP_ONEMINUS 18
#define OP_INVERT 19
#define OP_2MUL 20
#define OP_EBASE 21
#define OP_ELEN 22
#define OP_U8 23
#define OP_U16 24
#define OP_U32 25
#define OP_U64 26
/* Opcodes 27-42 were retired ELF-structure aliases. */
#define OP_AND 43
#define OP_OR 44
#define OP_XOR 45
#define OP_LSHIFT 46
#define OP_RSHIFT 47
#define OP_ULT 48
#define OP_UGT 49
#define OP_MIN 50
#define OP_MAX 51
#define OP_FOR 52
#define OP_I 53
#define OP_NEXT 54
#define OP_BRZ 55
#define OP_BR 56
#define OP_THEN 57
#define OP_MFETCH 58
#define OP_MSTORE 59
#define OP_UDIV 60
#define OP_I8FETCH 61
#define OP_I8STORE 62
#define OP_I64FETCH 63
#define OP_I64STORE 64
#define OP_ECOPY 65
#define OP_O64STORE 66
#define OP_OSMAP 67
#define OP_O64FETCH 68
#define OP_O8FETCH 69
#define OP_OSUNMAP 70
#define OP_OSPROTECT 71
#define OP_OSREAD 72
#define OP_OSCLOSE 73
#define OP_PBASE 74
#define OP_P8FETCH 75
#define OP_P8STORE 76
#define OP_ESOURCE 77
#define OP_OCALL 78
#define OP_STREQ 79
#define OP_OSCOPY 80
#define OP_CPUID 81
#define OP_CALL 82
#define OP_RET 83
#define OP_SYSCALL6 84
#define OP_LIT_INV 85
#define OP_ADD_ALT 86
#define OP_SUB_ALT 87
#define OP_EQ_ALT 88
#define OP_LT_ALT 89
#define OP_GT_ALT 90
#define OP_NOP_ALT 91
#define OP_BLOB64 92

#define TR_NOOP 1
#define TR_LIT_REWRITE 2
#define TR_STACK_EQUIV 3
#define TR_NEUTRAL_OP 4
#define TR_EQ_REWRITE 5
#define TR_DEPTH_NOOP 6
#define TR_POST_NEUTRAL 7
#define TR_SUB_REWRITE 8
#define TR_BOOL_NORM 9
#define TR_ZERO_LIT 10
#define TR_ZEROEQ_NORM 11
#define TR_INVERT_PAIR 12
#define TR_INCDEC_LIT 13
#define TR_2MUL_LIT 14

struct workspace_header {
    uint64_t magic;
    uint64_t seed;
    uint64_t flags;
    uint64_t original_tokens;
    uint64_t transformed_tokens;
    uint64_t transforms;
    int64_t status;
    uint64_t out_base;
    uint64_t original_base;
    uint64_t transformed_base;
    uint64_t trace_base;
    uint64_t trace_count;
    uint64_t max_depth;
    uint64_t final_depth;
    uint64_t error_at;
    int64_t validate_status;
    uint64_t scratch_base;
    uint64_t rounds;
    uint64_t rounds_done;
    uint64_t previous_base;
    uint64_t previous_tokens;
    uint64_t elf_base;
    uint64_t elf_len;
    uint64_t control_depth;
    uint64_t service_map;
    uint64_t service_unmap;
    uint64_t service_protect;
    uint64_t service_read_file;
    uint64_t service_close;
    uint64_t service_context;
    uint64_t service_copy;
    uint64_t word_meta;
};

typedef uint64_t (*forth_os_service_fn)(void *, uint64_t, uint64_t, uint64_t, uint64_t);
/* read-file args: exact path address, path length, empty source slot, capacity;
 * returns an open handle or a negative errno encoded as uint64_t. */

enum forth_object_field {
    FORTH_OBJECT_STATE = 0,
    FORTH_OBJECT_SOURCE_KIND = 1,
    FORTH_OBJECT_SOURCE_ADDR = 2,
    FORTH_OBJECT_SOURCE_SIZE = 3,
    FORTH_OBJECT_MAP_BASE = 4,
    FORTH_OBJECT_LOW_VADDR = 5,
    FORTH_OBJECT_HIGH_VADDR = 6,
    FORTH_OBJECT_ENTRY = 7,
    FORTH_OBJECT_MAP_SIZE = 8,
    FORTH_OBJECT_STRTAB = 9,
    FORTH_OBJECT_SYMTAB = 10,
    FORTH_OBJECT_HASH = 11,
    FORTH_OBJECT_GNU_HASH = 12,
    FORTH_OBJECT_VERSYM = 13,
    FORTH_OBJECT_VERNEED = 14,
    FORTH_OBJECT_SYMENT = 15,
};

#endif
