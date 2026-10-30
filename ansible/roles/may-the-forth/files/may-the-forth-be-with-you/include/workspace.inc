%define WS_MAGIC_VALUE  0x465448504f435031
%define WS_MAGIC       0
%define WS_SEED        8
%define WS_FLAGS       16
%define WS_ORIG        24
%define WS_XTOK        32
%define WS_XFORMS      40
%define WS_STATUS      48
%define WS_OUTBASE     56
%define WS_ORIG_BASE   64
%define WS_XFORM_BASE  72
%define WS_TRACE_BASE  80
%define WS_TRACE_COUNT 88
%define WS_MAX_DEPTH   96
%define WS_FINAL_DEPTH 104
%define WS_ERROR_AT    112
%define WS_VALIDATE    120
%define WS_SCRATCH_BASE 128
%define WS_ROUNDS      136
%define WS_ROUNDS_DONE 144
%define WS_PREV_BASE   152
%define WS_PREV_COUNT  160
%define WS_ELF_BASE    168
%define WS_ELF_LEN     176
%define WS_CTRL_DEPTH  184
%define WS_DICT_COUNT_SHIFT 51 ; packed into unused high WS_WORD_META bits
%define WS_SVC_MAP     192
%define WS_SVC_UNMAP   200
%define WS_SVC_PROTECT 208
%define WS_SVC_READ_FILE 216
%define WS_SVC_CLOSE   224
%define WS_SVC_CONTEXT 232
%define WS_SVC_COPY    240
%define WS_WORD_META   248
%define WS_HDR_SIZE    256

%define STACK_CELLS    64
%define STACK_SIZE     512
%define DATA_BASE_OFF  768
%define DATA_CELLS     2013
%define FORTH_LOADER_PASS 1023
%define FORTH_OBJECT_RECORD_BASE 256
%define FORTH_OBJECT_RECORD_MAX 48
%define IMAGE_BASE_OFF 16896
%define IMAGE_SIZE     458240
%define FORTH_SOURCE_SIZE_MAX 16777216
%define ORIG_BASE_OFF  475136
%define XFORM_BASE_OFF 677888
%define TRACE_BASE_OFF 1064960
%define SCRATCH_BASE_OFF 1073152
%define WORKSPACE_SIZE 2097152
%define PATH_BUFFER_SIZE 4096
%define PATH_BUFFER_BASE_OFF (WORKSPACE_SIZE - PATH_BUFFER_SIZE)
%define TRACE_ENTRY_SIZE 32
%define TRACE_LIMIT     256
%define MAX_ROUNDS      4
%if DATA_BASE_OFF + DATA_CELLS * 8 > IMAGE_BASE_OFF
    %error "data region overlaps image region"
%elif IMAGE_BASE_OFF + IMAGE_SIZE > ORIG_BASE_OFF
    %error "image region overlaps original-bytecode region"
%elif ORIG_BASE_OFF >= XFORM_BASE_OFF
    %error "original-bytecode region overlaps transform region"
%elif XFORM_BASE_OFF >= TRACE_BASE_OFF
    %error "transform region overlaps trace region"
%elif TRACE_BASE_OFF + TRACE_ENTRY_SIZE * TRACE_LIMIT > SCRATCH_BASE_OFF
    %error "trace region overlaps scratch region"
%elif SCRATCH_BASE_OFF >= WORKSPACE_SIZE
    %error "scratch region lies outside workspace"
%elif SCRATCH_BASE_OFF >= PATH_BUFFER_BASE_OFF
    %error "scratch region overlaps path buffer"
%elif PATH_BUFFER_BASE_OFF + PATH_BUFFER_SIZE != WORKSPACE_SIZE
    %error "path buffer must end at workspace boundary"
%endif
%define DICT_ENTRY_SIZE 48
%define DICT_CONST      1
%define DICT_INLINE     2
%define DICT_CALLABLE   3
%define CALLABLE_FLAG   4
%define SYSCALL_SERVICES_FLAG 8
%define RETURN_LIMIT    32
%define RETURN_BASE_OFF (IMAGE_BASE_OFF + 48640)
%define LAYOUT_CURSOR_OFF (IMAGE_BASE_OFF + 48000)
%define FIELD_CURSOR_OFF  (IMAGE_BASE_OFF + 48008)
%define LAYOUT_HIGH_OFF   (IMAGE_BASE_OFF + 48016)

%define OP_LIT   1
%define OP_DUP   2
%define OP_DROP  3
%define OP_SWAP  4
%define OP_OVER  5
%define OP_ADD   6
%define OP_SUB   7
%define OP_MUL   8
%define OP_EQ    9
%define OP_LT    10
%define OP_GT    11
%define OP_DOT   12
%define OP_EMIT  13
%define OP_CR    14
%define OP_NEG   15
%define OP_ZEROEQ 16
%define OP_ONEPLUS 17
%define OP_ONEMINUS 18
%define OP_INVERT 19
%define OP_2MUL 20
%define OP_EBASE 21
%define OP_ELEN 22
%define OP_U8 23
%define OP_U16 24
%define OP_U32 25
%define OP_U64 26
; Opcodes 27-42 were retired ELF-structure aliases. Keep the generic u* reads.
%define OP_AND 43
%define OP_OR 44
%define OP_XOR 45
%define OP_LSHIFT 46
%define OP_RSHIFT 47
%define OP_ULT 48
%define OP_UGT 49
%define OP_MIN 50
%define OP_MAX 51
%define OP_FOR 52
%define OP_I 53
%define OP_NEXT 54
%define OP_BRZ 55
%define OP_BR 56
%define OP_THEN 57
%define OP_MFETCH 58
%define OP_MSTORE 59
%define OP_UDIV 60
%define OP_I8FETCH 61
%define OP_I8STORE 62
%define OP_I64FETCH 63
%define OP_I64STORE 64
%define OP_ECOPY 65
%define OP_O64STORE 66
%define OP_OSMAP 67
%define OP_O64FETCH 68
%define OP_O8FETCH 69
%define OP_OSUNMAP 70
%define OP_OSPROTECT 71
%define OP_OSREAD 72
%define OP_OSCLOSE 73
%define OP_PBASE 74
%define OP_P8FETCH 75
%define OP_P8STORE 76
%define OP_ESOURCE 77
%define OP_OCALL 78
%define OP_STREQ 79
%define OP_OSCOPY 80
%define OP_CPUID 81
%define OP_CALL  82
%define OP_RET   83
%define OP_SYSCALL6 84
%define OP_LIT_INV 85
%define OP_ADD_ALT 86
%define OP_SUB_ALT 87
%define OP_EQ_ALT 88
%define OP_LT_ALT 89
%define OP_GT_ALT 90
%define OP_NOP_ALT 91
%define OP_BLOB64 92

%define LOOP_STATE_SIZE 16
%define LOOP_LIMIT_OFF  (WS_HDR_SIZE + STACK_SIZE - 16)
%define LOOP_INDEX_OFF  (WS_HDR_SIZE + STACK_SIZE - 8)
%define CTRL_DEPTH_OFF  WS_CTRL_DEPTH
%define CTRL_BASE_OFF   WS_HDR_SIZE
%define CTRL_ENTRY_SIZE 32
%define CTRL_LIMIT      15
%define CTRL_FOR        1
%define CTRL_IF         2
%define CTRL_ELSE       3

%define TR_NOOP        1
%define TR_LIT_REWRITE 2
%define TR_STACK_EQUIV 3
%define TR_NEUTRAL_OP  4
%define TR_EQ_REWRITE  5
%define TR_DEPTH_NOOP  6
%define TR_POST_NEUTRAL 7
%define TR_SUB_REWRITE 8
%define TR_BOOL_NORM   9
%define TR_ZERO_LIT    10
%define TR_ZEROEQ_NORM 11
%define TR_INVERT_PAIR 12
%define TR_INCDEC_LIT  13
%define TR_2MUL_LIT    14

%define TRACE_FLAG     1
%define COMPILE_ONLY_FLAG 2
