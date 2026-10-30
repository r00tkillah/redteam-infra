WS_MAGIC_VALUE = 0x465448504F435031
WORKSPACE_SIZE = 2097152
DATA_BASE_OFF = 768
DATA_CELLS = 2013
IMAGE_BASE_OFF = 16896
IMAGE_SIZE = 458240
FORTH_SOURCE_SIZE_MAX = 16777216
FORTH_OBJECT_MAP_MAX = 16777216
ORIG_BASE_OFF = 475136
ORIG_SIZE = 202752
XFORM_BASE_OFF = 677888
XFORM_SIZE = 387072
TRACE_BASE_OFF = 1064960
TRACE_SIZE = 8192
SCRATCH_BASE_OFF = 1073152
PATH_BUFFER_SIZE = 4096
PATH_BUFFER_BASE_OFF = WORKSPACE_SIZE - PATH_BUFFER_SIZE
SCRATCH_SIZE = PATH_BUFFER_BASE_OFF - SCRATCH_BASE_OFF
FORTH_OBJECT_RECORD_BASE = 256
FORTH_OBJECT_RECORD_SIZE = 16
FORTH_OBJECT_RECORD_MAX = 48
OUTPUT_SIZE = 8192
MAX_TRANSFORM_ROUNDS = 4
WS_FLAG_COMPILE_ONLY = 2
WS_FLAG_CALLABLE = 4
WS_FLAG_SYSCALL_SERVICES = 8
WS_ROUNDS_OFF = 136
WS_FLAGS_OFF = 16
WS_ELF_BASE_OFF = 168
WS_ELF_LEN_OFF = 176
WS_CTRL_DEPTH_OFF = 184
WS_SERVICE_MAP_OFF = 192
WS_SERVICE_UNMAP_OFF = 200
WS_SERVICE_PROTECT_OFF = 208
WS_SERVICE_READ_FILE_OFF = 216
WS_SERVICE_CLOSE_OFF = 224
WS_SERVICE_CONTEXT_OFF = 232

OP = {
    "LIT": 1,
    "DUP": 2,
    "DROP": 3,
    "SWAP": 4,
    "OVER": 5,
    "ADD": 6,
    "SUB": 7,
    "MUL": 8,
    "EQ": 9,
    "LT": 10,
    "GT": 11,
    "DOT": 12,
    "EMIT": 13,
    "CR": 14,
    "NEG": 15,
    "ZEROEQ": 16,
    "ONEPLUS": 17,
    "ONEMINUS": 18,
    "INVERT": 19,
    "2MUL": 20,
    "EBASE": 21,
    "ELEN": 22,
    "U8": 23,
    "U16": 24,
    "U32": 25,
    "U64": 26,
    "AND": 43,
    "OR": 44,
    "XOR": 45,
    "LSHIFT": 46,
    "RSHIFT": 47,
    "ULT": 48,
    "UGT": 49,
    "MIN": 50,
    "MAX": 51,
    "FOR": 52,
    "I": 53,
    "NEXT": 54,
    "BRZ": 55,
    "BR": 56,
    "THEN": 57,
    "MFETCH": 58,
    "MSTORE": 59,
    "UDIV": 60,
    "I8FETCH": 61,
    "I8STORE": 62,
    "I64FETCH": 63,
    "I64STORE": 64,
    "ECOPY": 65,
    "O64STORE": 66,
    "OSMAP": 67,
    "O64FETCH": 68,
    "O8FETCH": 69,
    "OSUNMAP": 70,
    "OSPROTECT": 71,
    "OSREAD": 72,
    "OSCLOSE": 73,
    "PBASE": 74,
    "P8FETCH": 75,
    "P8STORE": 76,
    "ESOURCE": 77,
    "OCALL": 78,
}

TRACE = {
    "NOOP": 1,
    "LIT_REWRITE": 2,
    "STACK_EQUIV": 3,
    "NEUTRAL_OP": 4,
    "EQ_REWRITE": 5,
    "DEPTH_NOOP": 6,
    "POST_NEUTRAL": 7,
    "SUB_REWRITE": 8,
    "BOOL_NORM": 9,
    "ZERO_LIT": 10,
    "ZEROEQ_NORM": 11,
    "INVERT_PAIR": 12,
    "INCDEC_LIT": 13,
    "2MUL_LIT": 14,
}

WORKSPACE_META_STRUCT = "<QQQQQqQQQQQQQQqQQQQQQQQ"


def validate_workspace_layout():
    regions = (
        ("data", DATA_BASE_OFF, DATA_CELLS * 8),
        ("image", IMAGE_BASE_OFF, IMAGE_SIZE),
        ("original", ORIG_BASE_OFF, ORIG_SIZE),
        ("transform", XFORM_BASE_OFF, XFORM_SIZE),
        ("trace", TRACE_BASE_OFF, TRACE_SIZE),
        ("scratch", SCRATCH_BASE_OFF, SCRATCH_SIZE),
        ("path", PATH_BUFFER_BASE_OFF, PATH_BUFFER_SIZE),
    )
    previous_end = 0
    for name, start, size in regions:
        if size <= 0 or start < previous_end or start + size > WORKSPACE_SIZE:
            raise ValueError(f"invalid or overlapping {name} workspace region")
        previous_end = start + size
    return regions


validate_workspace_layout()
