bits 64
default rel

section .text
global blob_entry
global forth_entry

%include "include/workspace.inc"

%define BOOT_MAGIC 0x31544f4f42485446
%define BUNDLE_MAGIC 0x314c444e42485446

blob_entry:
%ifdef EMBEDDED_BUNDLE
    jmp embedded_entry
%else
    test rdi, rdi
    jz standalone_fail
    mov rax, BOOT_MAGIC
    cmp [rdi], rax
    je standalone_entry
%ifdef STANDALONE_ONLY
    jmp standalone_fail
%else
    jmp forth_entry
%endif
%endif

%ifdef EMBEDDED_BUNDLE
embedded_entry:
    xor r12d, r12d
    test rdi, rdi
    jz .boot_ready
    mov rax, BOOT_MAGIC
    cmp [rdi], rax
    jne standalone_fail
    cmp qword [rdi + 8], 2
    jne standalone_fail
    mov rax, [rdi + 64]
    test rax, rax
    jz standalone_fail
    cmp rax, [rel embedded_manifest + 16]
    jne standalone_fail
    mov r12, rdi
.boot_ready:
    mov rax, BUNDLE_MAGIC
    cmp qword [rel embedded_manifest], rax
    jne standalone_fail
    cmp qword [rel embedded_manifest + 8], 1
    jne standalone_fail
    lea rdx, [rel blob_entry]
    mov r14, [rel embedded_manifest + 24]
    mov r15, [rel embedded_manifest + 32]
    test r14, r14
    jz standalone_fail
    test r15, r15
    jz standalone_fail
    cmp r15, FORTH_SOURCE_SIZE_MAX
    ja standalone_fail
    mov rax, embedded_template_end - blob_entry
    cmp r14, rax
    jb standalone_fail
    mov rax, r14
    add rax, r15
    jc standalone_fail
    cmp rax, [rel embedded_manifest + 16]
    jne standalone_fail
    add r14, rdx
    jc standalone_fail
    cmp qword [rel embedded_manifest + 40], 1
    jne standalone_fail
    cmp qword [rel embedded_manifest + 48], 1
    jne standalone_fail
    mov rax, [rel embedded_manifest + 56]
    or rax, [rel embedded_manifest + 64]
    or rax, [rel embedded_manifest + 72]
    jnz standalone_fail
    jmp standalone_embedded_ready
%endif

standalone_entry:
    cmp qword [rdi + 8], 1
    jne standalone_fail
    mov r12, rdi
    mov rax, [rdi + 16]
    test rax, rax
    jz standalone_fail
    mov rax, [rdi + 24]
    test rax, rax
    jz standalone_fail
    cmp rax, 255
    ja standalone_fail
    mov eax, 9
    xor edi, edi
    mov esi, WORKSPACE_SIZE
    mov edx, 3
    mov r10d, 0x22
    mov r8, -1
    xor r9d, r9d
    syscall
    cmp rax, -4095
    jae standalone_fail
    mov rbx, rax
    mov eax, 9
    xor edi, edi
    mov esi, 8192
    mov edx, 3
    mov r10d, 0x22
    mov r8, -1
    xor r9d, r9d
    syscall
    cmp rax, -4095
    jae standalone_fail
    mov r13, rax
standalone_workspace_ready:
    mov rax, WS_MAGIC_VALUE
    mov [rbx + WS_MAGIC], rax
    mov qword [rbx + WS_SEED], 1
    mov qword [rbx + WS_FLAGS], CALLABLE_FLAG | SYSCALL_SERVICES_FLAG
    mov qword [rbx + WS_ROUNDS], 2
%ifdef EMBEDDED_BUNDLE
    mov qword [rbx + DATA_BASE_OFF + 1821 * 8], 5
    mov [rbx + WS_ELF_BASE], r14
    mov [rbx + WS_ELF_LEN], r15
    mov qword [rbx + DATA_BASE_OFF + 256 * 8 + 1 * 8], 1
    mov [rbx + DATA_BASE_OFF + 256 * 8 + 2 * 8], r14
    mov [rbx + DATA_BASE_OFF + 256 * 8 + 3 * 8], r15
%else
    mov qword [rbx + DATA_BASE_OFF + 1821 * 8], 4
    mov rcx, [r12 + 24]
    mov [rbx + DATA_BASE_OFF + 1696 * 8], rcx
    mov rsi, [r12 + 16]
    lea rdi, [rbx + PATH_BUFFER_BASE_OFF + 3840]
.bootstrap_path_copy:
    test rcx, rcx
    jz .bootstrap_path_done
    mov al, [rsi]
    test al, al
    jz standalone_fail
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jmp .bootstrap_path_copy
.bootstrap_path_done:
    mov byte [rdi], 0
%endif
    sub rsp, 8
    mov r15d, 96
.standalone_phase:
    lea rdi, [rel loader_source]
    mov rsi, loader_source_end - loader_source
    mov rdx, r13
    mov rcx, 8192
    mov r8, rbx
    mov r9, WORKSPACE_SIZE
    call forth_entry
    test rax, rax
    js standalone_fail
    cmp qword [rbx + DATA_BASE_OFF + 1949 * 8], -1
    jne .standalone_more
    mov r14, rax
    jmp standalone_done
.standalone_more:
    dec r15
    jnz .standalone_phase
    jmp standalone_fail

standalone_done:
    cmp qword [rbx + DATA_BASE_OFF + 1694 * 8], 0
    jne standalone_fail
    mov rcx, [rbx + DATA_BASE_OFF + 1790 * 8]
    cmp rcx, 48
    ja standalone_fail
    xor edx, edx
.standalone_required_check:
    cmp rdx, rcx
    jae .standalone_ifunc_check
    mov rax, [rbx + DATA_BASE_OFF + 1870 * 8 + rdx * 8]
    mov eax, eax
    test rax, rax
    jnz standalone_fail
    inc rdx
    jmp .standalone_required_check
.standalone_ifunc_check:
    cmp qword [rbx + DATA_BASE_OFF + 1689 * 8], 0
    je .standalone_target_ready
    cmp qword [rbx + DATA_BASE_OFF + 1690 * 8], 0
    je standalone_fail
.standalone_target_ready:
    mov rax, [rbx + DATA_BASE_OFF + 256 * 8 + 4 * 8]
    mov rdx, [rbx + DATA_BASE_OFF + 256 * 8 + 7 * 8]
    mov edx, edx
    mov rcx, [rbx + DATA_BASE_OFF + 256 * 8 + 5 * 8]
    test rax, rax
    jz standalone_fail
    cmp rdx, rcx
    jb standalone_fail
    sub rdx, rcx
    cmp rdx, [rbx + DATA_BASE_OFF + 256 * 8 + 8 * 8]
    jae standalone_fail
    add rax, rdx
    mov r14, rax             ; original program entry
    mov eax, 9
    xor edi, edi
    mov esi, 1048576
    mov edx, 3
    mov r10d, 0x22
    mov r8, -1
    xor r9d, r9d
    syscall
    cmp rax, -4095
    jae standalone_fail
    lea r10, [rax + 524288]
    lea r13, [rax + 1048576 - 8192]
    mov eax, 102                    ; getuid
    syscall
    mov [rbx + DATA_BASE_OFF + 1697 * 8], rax
    mov eax, 107                    ; geteuid
    syscall
    mov [rbx + DATA_BASE_OFF + 1698 * 8], rax
    mov eax, 104                    ; getgid
    syscall
    mov [rbx + DATA_BASE_OFF + 1699 * 8], rax
    mov eax, 108                    ; getegid
    syscall
    mov [rbx + DATA_BASE_OFF + 1700 * 8], rax
    mov r8, r10              ; internal argv[0]
%ifdef EMBEDDED_BUNDLE
    lea rsi, [rel embedded_argv0]
    mov ecx, embedded_argv0_end - embedded_argv0
%else
    mov rcx, [r12 + 24]
    mov rsi, [r12 + 16]
%endif
.stack_path_copy:
    test rcx, rcx
    jz .stack_path_done
    mov dl, [rsi]
    mov [r10], dl
    inc rsi
    inc r10
    dec rcx
    jmp .stack_path_copy
.stack_path_done:
    mov byte [r10], 0
    mov rcx, r8
    sub rcx, 32
    rdtsc
    mov [rcx], rax
    not rax
    mov [rcx + 8], rax
    mov r15, rcx             ; AT_RANDOM payload
    mov rsp, rcx
    sub rsp, 4096
    and rsp, -16
    mov r11, rsp
%ifdef EMBEDDED_BUNDLE
    xor ecx, ecx
    test r12, r12
    jz .stack_argc_default
%endif
    mov rcx, [r12 + 40]
    test rcx, rcx
    jnz .stack_argc_ready
.stack_argc_default:
    mov ecx, 1
.stack_argc_ready:
    cmp rcx, 16
    ja standalone_fail
    mov [r11], rcx
    add r11, 8
%ifdef EMBEDDED_BUNDLE
    xor edx, edx
    test r12, r12
    jz .stack_argv_pointer_ready
%endif
    mov rdx, [r12 + 48]
%ifdef EMBEDDED_BUNDLE
.stack_argv_pointer_ready:
%endif
    xor edi, edi
.stack_argv_loop:
    cmp rdi, rcx
    jae .stack_argv_done
    mov rax, r8
    test rdi, rdi
    jz .stack_argv_write
    test rdx, rdx
    jz standalone_fail
    mov rax, [rdx + rdi * 8]
    test rax, rax
    jz standalone_fail
    mov rsi, rax
    mov rax, r10
.stack_arg_copy:
    cmp r10, r13
    jae standalone_fail
    mov r9b, [rsi]
    mov [r10], r9b
    inc rsi
    inc r10
    test r9b, r9b
    jnz .stack_arg_copy
.stack_argv_write:
    mov [r11], rax
    add r11, 8
    inc rdi
    jmp .stack_argv_loop
.stack_argv_done:
    mov qword [r11], 0
    add r11, 8
    mov [rbx + DATA_BASE_OFF + 1708 * 8], r11 ; target envp vector
%ifdef EMBEDDED_BUNDLE
    xor edx, edx
    test r12, r12
    jz .stack_env_pointer_ready
%endif
    mov rdx, [r12 + 56]
%ifdef EMBEDDED_BUNDLE
.stack_env_pointer_ready:
%endif
    xor edi, edi
.stack_env_loop:
    cmp rdi, 128
    jae .stack_env_done
    test rdx, rdx
    jz .stack_env_done
    mov rax, [rdx + rdi * 8]
    test rax, rax
    jz .stack_env_done
    mov rsi, rax
    mov rax, r10
.stack_env_copy:
    cmp r10, r13
    jae standalone_fail
    mov r9b, [rsi]
    mov [r10], r9b
    inc rsi
    inc r10
    test r9b, r9b
    jnz .stack_env_copy
    mov [r11], rax
    add r11, 8
    inc rdi
    jmp .stack_env_loop
.stack_env_done:
    mov qword [r11], 0
    add r11, 8
    mov rdx, [rbx + DATA_BASE_OFF + 256 * 8 + 2 * 8]
    mov rax, [rdx + 32]
    add rax, [rbx + DATA_BASE_OFF + 256 * 8 + 4 * 8]
    mov rsi, [rdx + 54]
    and rsi, 0xffff
    mov rdi, [rdx + 56]
    and rdi, 0xffff
    mov qword [r11], 25              ; AT_RANDOM
    mov [r11 + 8], r15
    mov qword [r11 + 16], 6          ; AT_PAGESZ
    mov qword [r11 + 24], 4096
    mov qword [r11 + 32], 3          ; AT_PHDR
    mov [r11 + 40], rax
    mov qword [r11 + 48], 4          ; AT_PHENT
    mov [r11 + 56], rsi
    mov qword [r11 + 64], 5          ; AT_PHNUM
    mov [r11 + 72], rdi
    mov qword [r11 + 80], 9          ; AT_ENTRY
    mov [r11 + 88], r14
    mov qword [r11 + 96], 31         ; AT_EXECFN
    mov [r11 + 104], r8
    mov qword [r11 + 112], 7         ; AT_BASE
    mov rax, [rbx + DATA_BASE_OFF + 276 * 8]
    mov [r11 + 120], rax
    mov qword [r11 + 128], 11        ; AT_UID
    mov rax, [rbx + DATA_BASE_OFF + 1697 * 8]
    mov [r11 + 136], rax
    mov qword [r11 + 144], 12        ; AT_EUID
    mov rax, [rbx + DATA_BASE_OFF + 1698 * 8]
    mov [r11 + 152], rax
    mov qword [r11 + 160], 13        ; AT_GID
    mov rax, [rbx + DATA_BASE_OFF + 1699 * 8]
    mov [r11 + 168], rax
    mov qword [r11 + 176], 14        ; AT_EGID
    mov rax, [rbx + DATA_BASE_OFF + 1700 * 8]
    mov [r11 + 184], rax
    mov qword [r11 + 192], 23        ; AT_SECURE
    mov qword [r11 + 200], 0
    mov qword [r11 + 208], 0
    mov qword [r11 + 216], 0
    mov rax, [rbx + DATA_BASE_OFF + 1692 * 8]
    test rax, rax
    jz .stack_environ_ready
    dec rax
    imul rax, 7
    add rax, 1950 + 6
    mov rcx, [rbx + DATA_BASE_OFF + rax * 8]
    mov rax, [rbx + DATA_BASE_OFF + 1687 * 8]
    cmp rax, 48
    jae standalone_fail
    shl rax, 7
    lea rax, [rbx + DATA_BASE_OFF + 256 * 8 + rax]
    add rcx, [rax + 4 * 8]
    sub rcx, [rax + 5 * 8]
    mov r10, [rbx + DATA_BASE_OFF + 1708 * 8]
    mov [rcx], r10
.stack_environ_ready:
    mov rsi, [rbx + DATA_BASE_OFF + 1707 * 8]
    test rsi, rsi
    jz .stack_tls_ready
    mov eax, 158
    mov edi, 0x1002
    syscall
    test rax, rax
    jnz standalone_fail
.stack_tls_ready:
    xor ebp, ebp
    xor edx, edx
    xor edi, edi
    xor esi, esi
    xor r9d, r9d
    jmp r14

standalone_fail:
    mov eax, 1
    mov edi, 2
    lea rsi, [rel standalone_failure_text]
    mov edx, standalone_failure_text_end - standalone_failure_text
    syscall
    mov edi, 111
    mov eax, 231
    syscall
    ud2

%ifdef EMBEDDED_BUNDLE
standalone_embedded_ready:
    mov eax, 9
    xor edi, edi
    mov esi, WORKSPACE_SIZE
    mov edx, 3
    mov r10d, 0x22
    mov r8, -1
    xor r9d, r9d
    syscall
    cmp rax, -4095
    jae standalone_fail
    mov rbx, rax
    mov eax, 9
    xor edi, edi
    mov esi, 8192
    mov edx, 3
    mov r10d, 0x22
    mov r8, -1
    xor r9d, r9d
    syscall
    cmp rax, -4095
    jae standalone_fail
    mov r13, rax
    jmp standalone_workspace_ready
%endif

%define ERR_UNKNOWN   -1
%define ERR_UNDERFLOW -2
%define ERR_BADNUM    -3
%define ERR_OUT       -4
%define ERR_WORK      -5
%define ERR_DIVZERO   -6

; ABI:
; rdi=input, rsi=input_len, rdx=output, rcx=output_cap,
; r8=workspace, r9=workspace_len. Returns bytes written or negative errno.
forth_entry:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    mov rbx, r8
    cmp r9, WORKSPACE_SIZE
    jb .work_error

    mov qword [rbx + WS_ORIG], 0
    mov qword [rbx + WS_XTOK], 0
    mov qword [rbx + WS_XFORMS], 0
    mov qword [rbx + WS_STATUS], 0
    mov qword [rbx + WS_TRACE_COUNT], 0
    mov qword [rbx + WS_MAX_DEPTH], 0
    mov qword [rbx + WS_FINAL_DEPTH], 0
    mov qword [rbx + WS_ERROR_AT], 0
    mov qword [rbx + WS_VALIDATE], 0
    mov qword [rbx + WS_ROUNDS_DONE], 0
    mov qword [rbx + WS_WORD_META], 0
    mov qword [rbx + CTRL_DEPTH_OFF], 0
    mov qword [rbx + LAYOUT_CURSOR_OFF], 0
    mov qword [rbx + FIELD_CURSOR_OFF], 0
    mov qword [rbx + LAYOUT_HIGH_OFF], 0
    lea rax, [rbx + IMAGE_BASE_OFF + 49152]
    mov [rbx + WS_PREV_BASE], rax
    mov qword [rbx + WS_PREV_COUNT], 0
    mov rax, [rbx + WS_ROUNDS]
    test rax, rax
    jnz .rounds_nonzero
    test qword [rbx + WS_FLAGS], COMPILE_ONLY_FLAG
    jnz .rounds_ok
    mov rax, 1
.rounds_nonzero:
    cmp rax, MAX_ROUNDS
    jbe .rounds_ok
    mov rax, MAX_ROUNDS
.rounds_ok:
    mov [rbx + WS_ROUNDS], rax
    mov [rbx + WS_OUTBASE], rdx
    lea rax, [rbx + ORIG_BASE_OFF]
    mov [rbx + WS_ORIG_BASE], rax
    lea rax, [rbx + XFORM_BASE_OFF]
    mov [rbx + WS_XFORM_BASE], rax
    lea rax, [rbx + TRACE_BASE_OFF]
    mov [rbx + WS_TRACE_BASE], rax
    lea rax, [rbx + SCRATCH_BASE_OFF]
    mov [rbx + WS_SCRATCH_BASE], rax

    mov r15, rdi
    lea r14, [rdi + rsi]
    mov r13, rdx
    lea r12, [rdx + rcx]
    lea rbp, [rbx + WS_HDR_SIZE]
    lea r11, [rbx + ORIG_BASE_OFF]
    lea r10, [rbx + XFORM_BASE_OFF]

    cmp rsi, 24
    jb .compile_loop
    mov rax, 0x32504d4854524f46
    cmp [r15], rax
    jne .compile_loop
    cmp dword [r15 + 8], 2
    jne .unknown_error
    mov eax, [r15 + 12]
    mov [rbx + WS_PREV_COUNT], rax
    mov eax, [r15 + 16]
    mov [rbx + WS_ORIG], rax
    mov eax, [r15 + 20]
    mov dword [rbx + WS_WORD_META], eax
    mov eax, [r15 + 12]
    mov word [rbx + WS_WORD_META + 4], ax
    add r15, 24
.unpack_body:
    mov rax, [rbx + WS_PREV_COUNT]
    mov [rbx + WS_ERROR_AT], rax
    test rax, rax
    je .unpack_main
    call unpack_uint
    jc .work_error
    lea r10, [rbx + rax]
    lea rdx, [rbx + IMAGE_BASE_OFF + 49152 + DICT_ENTRY_SIZE]
    cmp r10, rdx
    jb .work_error
    call unpack_uint
    jc .work_error
    test rax, rax
    jz .work_error
    mov rcx, rax
    mov rdx, rcx
    add rdx, MAX_ROUNDS
    shl rdx, 4
    lea rdx, [r10 + rdx]
    lea rax, [rbx + ORIG_BASE_OFF]
    cmp rdx, rax
    ja .work_error
    push rcx
    push r10
    mov r11, r10
.unpack_body_token:
    call unpack_token
    jc .work_error_pop2
    dec rcx
    jnz .unpack_body_token
    pop r10
    pop rcx
    mov rsi, r10
    call transform_callable_body
    lea r11, [r10 + rcx * 8]
    lea r11, [r11 + rcx * 8 - 16]
    mov rdx, MAX_ROUNDS
.unpack_body_pad:
    mov rax, [r11]
    mov rsi, [r11 + 8]
    mov [r11 + 16], rax
    mov [r11 + 24], rsi
    mov qword [r11], OP_NOP_ALT
    mov qword [r11 + 8], 0
    add r11, 16
    inc qword [rbx + WS_XFORMS]
    dec rdx
    jnz .unpack_body_pad
    dec qword [rbx + WS_PREV_COUNT]
    jmp .unpack_body
.unpack_main:
    lea r11, [rbx + ORIG_BASE_OFF]
    mov rcx, [rbx + WS_ORIG]
.unpack_main_token:
    test rcx, rcx
    jz .unpack_done
    call unpack_token
    jc .work_error
    dec rcx
    jmp .unpack_main_token
.unpack_done:
    cmp r15, r14
    jne .work_error
    mov qword [rbx + WS_PREV_COUNT], 0
    jmp .transform
.work_error_pop2:
    pop r10
    pop rcx
    jmp .work_error

%ifdef PACKED_LOADER
.compile_loop:
    jmp .unknown_error
%else
.compile_loop:
    call skip_ws
    cmp r15, r14
    jae .transform

    mov rdi, r15
    call scan_token
    ; rdi token ptr, rsi token len, r15 advanced

    call try_word
    jnc .compile_loop

    call parse_number
    jc .number_failed
    call compile_number
    jmp .compile_loop
%endif

.transform:
    cmp qword [rbx + CTRL_DEPTH_OFF], 0
    jne .unknown_error
    mov rax, [rbx + WS_ROUNDS]
    and rax, 7
    shl rax, 48
    or [rbx + WS_WORD_META], rax
    mov rax, [rbx + WS_PREV_COUNT]
    shl rax, WS_DICT_COUNT_SHIFT
    or [rbx + WS_WORD_META], rax
    cmp qword [rbx + WS_ROUNDS], 0
    jne .round_start
    lea rax, [rbx + ORIG_BASE_OFF]
    mov [rbx + WS_XFORM_BASE], rax
    mov rax, [rbx + WS_ORIG]
    mov [rbx + WS_XTOK], rax
    call validate_xform
    jc .unknown_error
    jmp .compile_only_success
.round_start:
    lea r8, [rbx + ORIG_BASE_OFF]
    mov r9, [rbx + WS_ORIG]
.round_loop:
    mov [rbx + WS_PREV_BASE], r8
    mov [rbx + WS_PREV_COUNT], r9
    lea rax, [rbx + XFORM_BASE_OFF]
    cmp r8, rax
    je .round_dest_scratch
.round_dest_xform:
    lea r11, [rbx + XFORM_BASE_OFF]
    lea r10, [rbx + TRACE_BASE_OFF]
    jmp .round_dest_ready
.round_dest_scratch:
    lea r11, [rbx + SCRATCH_BASE_OFF]
    lea r10, [rbx + PATH_BUFFER_BASE_OFF]
.round_dest_ready:
    mov [rbx + WS_XFORM_BASE], r11
    mov qword [rbx + WS_XTOK], 0
    mov r15, r8
    mov rax, r9
    shl rax, 4
    lea r14, [r15 + rax]
    xor rdi, rdi        ; transform-time simulated stack depth
.transform_loop:
    cmp r15, r14
    jae .validate_after_round
    ; Preserve room for one unchanged output token per remaining input token.
    ; This keeps large programs transformable for every requested round.
    mov rax, r14
    sub rax, r15
    add rax, 255
    and rax, -256
    add rax, r11
    cmp rax, r10
    jae .copy_remainder
    mov rax, [r15]
    mov rdx, [r15 + 8]
    add r15, 16

    cmp rax, OP_FOR
    je .skip_pre_noop
    cmp rax, OP_NEXT
    je .skip_pre_noop
    cmp rax, OP_BRZ
    je .skip_pre_noop
    cmp rax, OP_BR
    je .skip_pre_noop
    cmp rax, OP_THEN
    je .skip_pre_noop
    push rax
    push rdx
    call maybe_insert_noop
    pop rdx
    pop rax
.skip_pre_noop:

    cmp rax, OP_LIT
    jne .copy_token
    push rdx
    call next_rand
    and rax, 7
    mov rcx, rax
    pop rdx
    cmp rcx, 0
    je .copy_lit_token
    cmp rdx, 0
    je .lit_zero_variant
    cmp rcx, 2
    je .lit_add_zero
    cmp rcx, 3
    je .lit_mul_one
    cmp rcx, 4
    je .lit_oneplus_variant
    cmp rcx, 5
    je .lit_oneminus_variant
    cmp rcx, 6
    je .lit_twomul_variant
    cmp rcx, 7
    je .lit_invert_pair

.split_lit_variant:
    mov r9, rdx
    call next_rand
    mov r8, rax
    and r8, 7
    mov rax, OP_LIT
    mov rdx, r8
    call emit_xform_token
    jc .work_error
    mov rdx, r9
    sub rdx, r8
    mov rax, OP_LIT
    call emit_xform_token
    jc .work_error
    mov rax, OP_ADD
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_LIT_REWRITE
    mov rdx, OP_LIT
    mov r8, r9
    mov r9, 3
    call record_trace
    inc rdi
    jmp .transform_loop
.lit_add_zero:
    mov r9, rdx
    mov rax, OP_LIT
    call emit_xform_token
    jc .work_error
    mov rax, OP_LIT
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_ADD
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_NEUTRAL_OP
    mov rdx, OP_ADD
    mov r8, r9
    mov r9, 3
    call record_trace
    inc rdi
    jmp .transform_loop
.lit_mul_one:
    mov r9, rdx
    mov rax, OP_LIT
    call emit_xform_token
    jc .work_error
    mov rax, OP_LIT
    mov rdx, 1
    call emit_xform_token
    jc .work_error
    mov rax, OP_MUL
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_NEUTRAL_OP
    mov rdx, OP_MUL
    mov r8, r9
    mov r9, 3
    call record_trace
    inc rdi
    jmp .transform_loop
.lit_zero_variant:
    call next_rand
    and rax, 15
    inc rax
    mov r9, rax
    mov rdx, r9
    mov rax, OP_LIT
    call emit_xform_token
    jc .work_error
    mov rdx, r9
    mov rax, OP_LIT
    call emit_xform_token
    jc .work_error
    mov rax, OP_SUB
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_ZERO_LIT
    mov rdx, OP_SUB
    mov r8, r9
    mov r9, 3
    call record_trace
    inc rdi
    jmp .transform_loop
.lit_oneplus_variant:
    mov r9, rdx
    dec rdx
    mov rax, OP_LIT
    call emit_xform_token
    jc .work_error
    mov rax, OP_ONEPLUS
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_INCDEC_LIT
    mov rdx, OP_ONEPLUS
    mov r8, r9
    mov r9, 2
    call record_trace
    inc rdi
    jmp .transform_loop
.lit_oneminus_variant:
    mov r9, rdx
    inc rdx
    mov rax, OP_LIT
    call emit_xform_token
    jc .work_error
    mov rax, OP_ONEMINUS
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_INCDEC_LIT
    mov rdx, OP_ONEMINUS
    mov r8, r9
    mov r9, 2
    call record_trace
    inc rdi
    jmp .transform_loop
.lit_twomul_variant:
    test rdx, 1
    jnz .split_lit_variant
    mov r9, rdx
    sar rdx, 1
    mov rax, OP_LIT
    call emit_xform_token
    jc .work_error
    mov rax, OP_2MUL
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_2MUL_LIT
    mov rdx, OP_2MUL
    mov r8, r9
    mov r9, 2
    call record_trace
    inc rdi
    jmp .transform_loop
.lit_invert_pair:
    mov r9, rdx
    mov rax, OP_LIT
    call emit_xform_token
    jc .work_error
    mov rax, OP_INVERT
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_INVERT
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_INVERT_PAIR
    mov rdx, OP_INVERT
    mov r8, r9
    mov r9, 3
    call record_trace
    inc rdi
    jmp .transform_loop
.copy_lit_token:
    mov rax, OP_LIT
    jmp .copy_token
.maybe_depth_noop:
    cmp rdi, 1
    jb .done_depth_noop
    call next_rand
    and rax, 7
    cmp rax, 0
    je .emit_dup_drop
    cmp rdi, 2
    jb .done_depth_noop
    cmp rax, 1
    je .emit_swap_swap
    cmp rax, 2
    je .emit_over_drop
    jmp .done_depth_noop
.emit_dup_drop:
    mov rax, OP_DUP
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_DROP
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_DEPTH_NOOP
    mov rdx, OP_DUP
    mov r8, rdi
    mov r9, 2
    call record_trace
    jmp .done_depth_noop
.emit_swap_swap:
    mov rax, OP_SWAP
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_SWAP
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_DEPTH_NOOP
    mov rdx, OP_SWAP
    mov r8, rdi
    mov r9, 2
    call record_trace
    jmp .done_depth_noop
.emit_over_drop:
    mov rax, OP_OVER
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_DROP
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_DEPTH_NOOP
    mov rdx, OP_OVER
    mov r8, rdi
    mov r9, 2
    call record_trace
.done_depth_noop:
    ret
.maybe_eq_rewrite:
    push rax
    call next_rand
    mov rcx, rax
    pop rax
    test cl, 1
    jz .maybe_stack_equiv
    mov rax, OP_SUB
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_LIT
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_EQ
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_EQ_REWRITE
    mov rdx, OP_EQ
    xor r8, r8
    mov r9, 3
    call record_trace
    dec rdi
    call maybe_post_neutral
    call .maybe_depth_noop
    jmp .transform_loop
.maybe_sub_rewrite:
    push rax
    call next_rand
    mov rcx, rax
    pop rax
    test cl, 1
    jz .emit_copy_token
    mov rax, OP_NEG
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_ADD
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_SUB_REWRITE
    mov rdx, OP_NEG
    xor r8, r8
    mov r9, 2
    call record_trace
    dec rdi
    call maybe_post_neutral
    call .maybe_depth_noop
    jmp .transform_loop
.maybe_bool_norm:
    push rax
    call next_rand
    mov rcx, rax
    pop r8
    and rax, 3
    cmp rax, 0
    je .emit_zeroeq_norm
    cmp rax, 1
    jne .bool_fallback
    mov rax, r8
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    dec rdi
    mov rax, OP_LIT
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_EQ
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_LIT
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_EQ
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_BOOL_NORM
    mov rdx, OP_EQ
    xor r8, r8
    mov r9, 5
    call record_trace
    call maybe_post_neutral
    call .maybe_depth_noop
    jmp .transform_loop
.emit_zeroeq_norm:
    mov rax, r8
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    dec rdi
    mov rax, OP_ZEROEQ
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, OP_ZEROEQ
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_ZEROEQ_NORM
    mov rdx, OP_ZEROEQ
    xor r8, r8
    mov r9, 3
    call record_trace
    call maybe_post_neutral
    call .maybe_depth_noop
    jmp .transform_loop
.bool_fallback:
    mov rax, r8
    jmp .maybe_stack_equiv
.maybe_stack_equiv:
    push rax
    call next_rand
    mov rcx, rax
    pop rax
    and rcx, 3
    cmp rcx, 0
    jne .emit_copy_token
    mov r8, rax
    cmp rax, OP_LT
    jne .not_lt
    mov r8, OP_GT
    jmp .emit_stack_equiv
.not_lt:
    cmp rax, OP_GT
    jne .emit_stack_equiv
    mov r8, OP_LT
.emit_stack_equiv:
    mov rax, OP_SWAP
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    mov rax, r8
    xor rdx, rdx
    call emit_xform_token
    jc .work_error
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_STACK_EQUIV
    mov rdx, r8
    xor r8, r8
    mov r9, 2
    call record_trace
    dec rdi
    call maybe_post_neutral
    call .maybe_depth_noop
    jmp .transform_loop
.copy_token:
    cmp rax, OP_ADD
    je .maybe_stack_equiv
    cmp rax, OP_MUL
    je .maybe_stack_equiv
    cmp rax, OP_SUB
    je .maybe_sub_rewrite
    cmp rax, OP_EQ
    je .maybe_eq_rewrite
    cmp rax, OP_LT
    je .maybe_bool_norm
    cmp rax, OP_GT
    je .maybe_bool_norm
.emit_copy_token:
    cmp rax, OP_LIT
    je .emit_copy_now
    cmp rax, OP_CALL
    je .emit_copy_now
    xor rdx, rdx
.emit_copy_now:
    call emit_xform_token
    jc .work_error
    call update_transform_depth
    cmp rax, OP_LIT
    je .post_after_copy
    cmp rax, OP_NEG
    je .post_after_copy
    cmp rax, OP_ZEROEQ
    je .post_after_copy
    cmp rax, OP_ONEPLUS
    je .post_after_copy
    cmp rax, OP_ONEMINUS
    je .post_after_copy
    cmp rax, OP_INVERT
    je .post_after_copy
    cmp rax, OP_2MUL
    je .post_after_copy
    cmp rax, OP_DUP
    je .post_after_copy
    cmp rax, OP_OVER
    je .post_after_copy
    cmp rax, OP_ADD
    je .post_after_copy
    cmp rax, OP_SUB
    je .post_after_copy
    cmp rax, OP_MUL
    je .post_after_copy
    cmp rax, OP_EQ
    je .post_after_copy
    cmp rax, OP_LT
    je .post_after_copy
    cmp rax, OP_GT
    jne .after_post_copy
.post_after_copy:
    call maybe_post_neutral
.after_post_copy:
    cmp rax, OP_FOR
    je .skip_depth_noop
    cmp rax, OP_NEXT
    je .skip_depth_noop
    cmp rax, OP_BRZ
    je .skip_depth_noop
    cmp rax, OP_BR
    je .skip_depth_noop
    cmp rax, OP_THEN
    je .skip_depth_noop
    call .maybe_depth_noop
.skip_depth_noop:
    jmp .transform_loop

.copy_remainder:
    cmp r15, r14
    jae .validate_after_round
    mov rax, [r15]
    mov rdx, [r15 + 8]
    call emit_xform_token
    jc .work_error
    add r15, 16
    jmp .copy_remainder

.validate_after_round:
    call repair_branch_offsets
    jc .execute_previous
    call validate_xform
    jc .execute_previous
    inc qword [rbx + WS_ROUNDS_DONE]
    mov rax, [rbx + WS_ROUNDS_DONE]
    cmp rax, [rbx + WS_ROUNDS]
    jae .execute_transformed
    mov r8, [rbx + WS_XFORM_BASE]
    mov r9, [rbx + WS_XTOK]
    jmp .round_loop

%ifndef PACKED_LOADER
.execute_original:
    test qword [rbx + WS_FLAGS], COMPILE_ONLY_FLAG
    jnz .compile_only_success
    lea r15, [rbx + ORIG_BASE_OFF]
    mov rax, [rbx + WS_ORIG]
    shl rax, 4
    lea r14, [r15 + rax]
    jmp .exec_loop
%endif

.execute_previous:
    test qword [rbx + WS_FLAGS], COMPILE_ONLY_FLAG
    jnz .compile_only_success
    mov r15, [rbx + WS_PREV_BASE]
    mov rax, [rbx + WS_PREV_COUNT]
    shl rax, 4
    lea r14, [r15 + rax]
    jmp .exec_loop

%ifndef PACKED_LOADER
.number_failed:
    cmp rsi, 0
    je .unknown_error
    mov al, [rdi]
    cmp al, '-'
    je .badnum_error
    cmp al, '0'
    jb .unknown_error
    cmp al, '9'
    ja .unknown_error
    jmp .badnum_error
%endif

.execute_transformed:
    test qword [rbx + WS_FLAGS], COMPILE_ONLY_FLAG
    jnz .compile_only_success
    mov r15, [rbx + WS_XFORM_BASE]
    mov r11, [rbx + WS_XTOK]
    mov rax, r11
    shl rax, 4
    lea r14, [r15 + rax]
.exec_loop:
    cmp r15, r14
    jae .success
    mov rax, [r15]
    mov rdx, [r15 + 8]
    add r15, 16

    cmp rax, OP_LIT
    je .op_lit
    cmp rax, OP_LIT_INV
    je .op_lit_inv
    cmp rax, OP_DUP
    je .op_dup
    cmp rax, OP_DROP
    je .op_drop
    cmp rax, OP_SWAP
    je .op_swap
    cmp rax, OP_OVER
    je .op_over
    cmp rax, OP_ADD
    je .op_add
    cmp rax, OP_ADD_ALT
    je .op_add
    cmp rax, OP_SUB
    je .op_sub
    cmp rax, OP_SUB_ALT
    je .op_sub
    cmp rax, OP_MUL
    je .op_mul
    cmp rax, OP_EQ
    je .op_eq
    cmp rax, OP_EQ_ALT
    je .op_eq
    cmp rax, OP_LT
    je .op_lt
    cmp rax, OP_LT_ALT
    je .op_lt
    cmp rax, OP_GT
    je .op_gt
    cmp rax, OP_GT_ALT
    je .op_gt
    cmp rax, OP_DOT
    je .op_dot
    cmp rax, OP_EMIT
    je .op_emit
    cmp rax, OP_CR
    je .op_cr
    cmp rax, OP_NEG
    je .op_neg
    cmp rax, OP_ZEROEQ
    je .op_zeroeq
    cmp rax, OP_ONEPLUS
    je .op_oneplus
    cmp rax, OP_ONEMINUS
    je .op_oneminus
    cmp rax, OP_INVERT
    je .op_invert
    cmp rax, OP_2MUL
    je .op_2mul
    cmp rax, OP_EBASE
    je .op_ebase
    cmp rax, OP_ELEN
    je .op_elen
    cmp rax, OP_U8
    je .op_u8
    cmp rax, OP_U16
    je .op_u16
    cmp rax, OP_U32
    je .op_u32
    cmp rax, OP_U64
    je .op_u64
    cmp rax, OP_AND
    je .op_and
    cmp rax, OP_OR
    je .op_or
    cmp rax, OP_XOR
    je .op_xor
    cmp rax, OP_LSHIFT
    je .op_lshift
    cmp rax, OP_RSHIFT
    je .op_rshift
    cmp rax, OP_ULT
    je .op_ult
    cmp rax, OP_UGT
    je .op_ugt
    cmp rax, OP_MIN
    je .op_min
    cmp rax, OP_MAX
    je .op_max
    cmp rax, OP_FOR
    je .op_for
    cmp rax, OP_I
    je .op_i
    cmp rax, OP_NEXT
    je .op_next
    cmp rax, OP_BRZ
    je .op_brz
    cmp rax, OP_BR
    je .op_br
    cmp rax, OP_THEN
    je .exec_loop
    cmp rax, OP_NOP_ALT
    je .exec_loop
    cmp rax, OP_MFETCH
    je .op_mfetch
    cmp rax, OP_MSTORE
    je .op_mstore
    cmp rax, OP_UDIV
    je .op_udiv
    cmp rax, OP_I8FETCH
    je .op_i8fetch
    cmp rax, OP_I8STORE
    je .op_i8store
    cmp rax, OP_I64FETCH
    je .op_i64fetch
    cmp rax, OP_I64STORE
    je .op_i64store
    cmp rax, OP_ECOPY
    je .op_ecopy
    cmp rax, OP_O64STORE
    je .op_o64store
    cmp rax, OP_OSMAP
    je .op_osmap
    cmp rax, OP_O64FETCH
    je .op_o64fetch
    cmp rax, OP_O8FETCH
    je .op_o8fetch
    cmp rax, OP_OSUNMAP
    je .op_osunmap
    cmp rax, OP_OSPROTECT
    je .op_osprotect
    cmp rax, OP_OSREAD
    je .op_osread
    cmp rax, OP_OSCLOSE
    je .op_osclose
    cmp rax, OP_PBASE
    je .op_pbase
    cmp rax, OP_P8FETCH
    je .op_p8fetch
    cmp rax, OP_P8STORE
    je .op_p8store
    cmp rax, OP_ESOURCE
    je .op_esource
    cmp rax, OP_OCALL
    je .op_ocall
    cmp rax, OP_STREQ
    je .op_streq
    cmp rax, OP_OSCOPY
    je .op_oscopy
    cmp rax, OP_CPUID
    je .op_cpuid
    cmp rax, OP_CALL
    je .op_call
    cmp rax, OP_RET
    je .op_ret
    cmp rax, OP_SYSCALL6
    je .op_syscall6
    cmp rax, OP_BLOB64
    je .op_blob64
    jmp .unknown_error

.op_call:
    ; imm low32=workspace-relative body, high32=token count.
    mov rcx, rdx
    shr rcx, 32
    and rcx, 0xffff
    test rcx, rcx
    jz .work_error
    mov eax, edx
    lea r8, [rbx + rax]
    lea r9, [rbx + IMAGE_BASE_OFF + 49152 + DICT_ENTRY_SIZE]
    cmp r8, r9
    jb .work_error
    mov r9, rcx
    shl r9, 4
    lea r9, [r8 + r9]
    lea rax, [rbx + ORIG_BASE_OFF]
    cmp r9, rax
    ja .work_error
    mov rax, [rbx + CTRL_DEPTH_OFF]
    cmp rax, RETURN_LIMIT
    jae .work_error
    mov r9, rax
    shl r9, 4
    lea r9, [rbx + RETURN_BASE_OFF + r9]
    mov [r9], r15
    mov [r9 + 8], r14
    inc qword [rbx + CTRL_DEPTH_OFF]
    mov r15, r8
    mov r14, rcx
    shl r14, 4
    add r14, r8
    jmp .exec_loop

.op_ret:
    cmp qword [rbx + CTRL_DEPTH_OFF], 0
    je .work_error
    dec qword [rbx + CTRL_DEPTH_OFF]
    mov rax, [rbx + CTRL_DEPTH_OFF]
    shl rax, 4
    lea rax, [rbx + RETURN_BASE_OFF + rax]
    mov r15, [rax]
    mov r14, [rax + 8]
    jmp .exec_loop

.op_syscall6:
    ; (a1 a2 a3 a4 a5 a6 nr -- result), using the raw Linux x86-64 ABI.
    lea rax, [rbx + WS_HDR_SIZE]
    mov rcx, rbp
    sub rcx, rax
    cmp rcx, 56
    jb .underflow_error
    mov rdi, [rbp - 56]
    mov rsi, [rbp - 48]
    mov rdx, [rbp - 40]
    mov r10, [rbp - 32]
    mov r8, [rbp - 24]
    mov r9, [rbp - 16]
    mov rax, [rbp - 8]
    syscall
    sub rbp, 48
    mov [rbp - 8], rax
    jmp .exec_loop

.op_blob64:
    call need1
    jc .underflow_error
    mov rax, [rbp - 8]
    cmp rax, 63
    jae .work_error
    lea rdx, [rel adapter_data]
    mov rax, [rdx + rax * 8]
    mov [rbp - 8], rax
    jmp .exec_loop

.op_lit_inv:
    not rdx
.op_lit:
    push rdx
    call ensure_push
    pop rdx
    jc .work_error
    mov [rbp], rdx
    add rbp, 8
    call record_depth
    jmp .exec_loop

.op_dup:
    call need1
    jc .underflow_error
    call ensure_push
    jc .work_error
    mov rax, [rbp - 8]
    mov [rbp], rax
    add rbp, 8
    call record_depth
    jmp .exec_loop

.op_drop:
    call need1
    jc .underflow_error
    sub rbp, 8
    jmp .exec_loop

.op_swap:
    call need2
    jc .underflow_error
    mov rax, [rbp - 8]
    mov rdx, [rbp - 16]
    mov [rbp - 8], rdx
    mov [rbp - 16], rax
    jmp .exec_loop

.op_over:
    call need2
    jc .underflow_error
    call ensure_push
    jc .work_error
    mov rax, [rbp - 16]
    mov [rbp], rax
    add rbp, 8
    call record_depth
    jmp .exec_loop

.op_add:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    add rax, [rbp - 8]
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_sub:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    sub rax, [rbp - 8]
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_mul:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    imul rax, [rbp - 8]
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_eq:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    cmp rax, [rbp - 8]
    sete al
    movzx rax, al
    neg rax
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_lt:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    cmp rax, [rbp - 8]
    setl al
    movzx rax, al
    neg rax
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_gt:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    cmp rax, [rbp - 8]
    setg al
    movzx rax, al
    neg rax
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_dot:
    call need1
    jc .underflow_error
    sub rbp, 8
    mov rax, [rbp]
    call append_int
    jc .out_error
    mov al, ' '
    call append_char
    jc .out_error
    jmp .exec_loop

.op_emit:
    call need1
    jc .underflow_error
    sub rbp, 8
    mov rax, [rbp]
    call append_char
    jc .out_error
    jmp .exec_loop

.op_cr:
    mov al, 10
    call append_char
    jc .out_error
    jmp .exec_loop

.op_neg:
    call need1
    jc .underflow_error
    neg qword [rbp - 8]
    jmp .exec_loop

.op_zeroeq:
    call need1
    jc .underflow_error
    cmp qword [rbp - 8], 0
    sete al
    movzx rax, al
    neg rax
    mov [rbp - 8], rax
    jmp .exec_loop

.op_oneplus:
    call need1
    jc .underflow_error
    inc qword [rbp - 8]
    jmp .exec_loop

.op_oneminus:
    call need1
    jc .underflow_error
    dec qword [rbp - 8]
    jmp .exec_loop

.op_invert:
    call need1
    jc .underflow_error
    not qword [rbp - 8]
    jmp .exec_loop

.op_2mul:
    call need1
    jc .underflow_error
    shl qword [rbp - 8], 1
    jmp .exec_loop

.op_ebase:
    mov rax, [rbx + WS_ELF_BASE]
    call push_rax
    jc .work_error
    jmp .exec_loop

.op_elen:
    mov rax, [rbx + WS_ELF_LEN]
    call push_rax
    jc .work_error
    jmp .exec_loop

.op_u8:
    mov rcx, 1
    call pop_elf_offset
    jc .underflow_error
    call read_elf_u8
    jc .work_error
    call push_rax
    jc .work_error
    jmp .exec_loop

.op_u16:
    mov rcx, 2
    call pop_elf_offset
    jc .underflow_error
    call read_elf_u16
    jc .work_error
    call push_rax
    jc .work_error
    jmp .exec_loop

.op_u32:
    mov rcx, 4
    call pop_elf_offset
    jc .underflow_error
    call read_elf_u32
    jc .work_error
    call push_rax
    jc .work_error
    jmp .exec_loop

.op_u64:
    mov rcx, 8
    call pop_elf_offset
    jc .underflow_error
    call read_elf_u64
    jc .work_error
    call push_rax
    jc .work_error
    jmp .exec_loop

.op_and:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    and rax, [rbp - 8]
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_or:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    or rax, [rbp - 8]
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_xor:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    xor rax, [rbp - 8]
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_lshift:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    mov rcx, [rbp - 8]
    and rcx, 63
    shl rax, cl
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_rshift:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    mov rcx, [rbp - 8]
    and rcx, 63
    shr rax, cl
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_ult:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    cmp rax, [rbp - 8]
    setb al
    movzx rax, al
    neg rax
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_ugt:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    cmp rax, [rbp - 8]
    seta al
    movzx rax, al
    neg rax
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_min:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    mov rdx, [rbp - 8]
    cmp rax, rdx
    cmovg rax, rdx
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_max:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    mov rdx, [rbp - 8]
    cmp rax, rdx
    cmovl rax, rdx
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_for:
    call need1
    jc .underflow_error
    sub rbp, 8
    mov rax, [rbp]
    test rax, rax
    jle .op_for_skip
    mov [rbx + LOOP_LIMIT_OFF], rax
    mov qword [rbx + LOOP_INDEX_OFF], 0
    jmp .exec_loop
.op_for_skip:
    shl rdx, 4
    add r15, rdx
    jmp .exec_loop

.op_i:
    mov rax, [rbx + LOOP_INDEX_OFF]
    call push_rax
    jc .work_error
    jmp .exec_loop

.op_next:
    inc qword [rbx + LOOP_INDEX_OFF]
    mov rax, [rbx + LOOP_INDEX_OFF]
    cmp rax, [rbx + LOOP_LIMIT_OFF]
    jae .exec_loop
    shl rdx, 4
    add r15, rdx
    jmp .exec_loop

.op_brz:
    call need1
    jc .underflow_error
    sub rbp, 8
    cmp qword [rbp], 0
    jne .exec_loop
    shl rdx, 4
    add r15, rdx
    jmp .exec_loop

.op_br:
    shl rdx, 4
    add r15, rdx
    jmp .exec_loop

.op_mfetch:
    call need1
    jc .underflow_error
    mov rax, [rbp - 8]
    cmp rax, DATA_CELLS
    jae .work_error
    mov rax, [rbx + DATA_BASE_OFF + rax * 8]
    mov [rbp - 8], rax
    jmp .exec_loop

.op_mstore:
    call need2
    jc .underflow_error
    mov rax, [rbp - 8]
    cmp rax, DATA_CELLS
    jae .work_error
    mov rdx, [rbp - 16]
    mov [rbx + DATA_BASE_OFF + rax * 8], rdx
    sub rbp, 16
    jmp .exec_loop

.op_udiv:
    call need2
    jc .underflow_error
    mov rcx, [rbp - 8]
    test rcx, rcx
    jz .divzero_error
    mov rax, [rbp - 16]
    xor rdx, rdx
    div rcx
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_i8fetch:
    call need1
    jc .underflow_error
    mov rdx, [rbp - 8]
    mov rcx, 1
    call check_image_bounds
    jc .work_error
    movzx rax, byte [rbx + IMAGE_BASE_OFF + rdx]
    mov [rbp - 8], rax
    jmp .exec_loop

.op_i8store:
    call need2
    jc .underflow_error
    mov rdx, [rbp - 8]
    mov rcx, 1
    call check_image_bounds
    jc .work_error
    mov rax, [rbp - 16]
    mov [rbx + IMAGE_BASE_OFF + rdx], al
    sub rbp, 16
    jmp .exec_loop

.op_i64fetch:
    call need1
    jc .underflow_error
    mov rdx, [rbp - 8]
    mov rcx, 8
    call check_image_bounds
    jc .work_error
    mov rax, [rbx + IMAGE_BASE_OFF + rdx]
    mov [rbp - 8], rax
    jmp .exec_loop

.op_i64store:
    call need2
    jc .underflow_error
    mov rdx, [rbp - 8]
    mov rcx, 8
    call check_image_bounds
    jc .work_error
    mov rax, [rbp - 16]
    mov [rbx + IMAGE_BASE_OFF + rdx], rax
    sub rbp, 16
    jmp .exec_loop

.op_ecopy:
    call need4
    jc .underflow_error
    mov r8, [rbp - 32]       ; ELF source offset
    mov r9, [rbp - 24]       ; object destination offset
    mov r10, [rbp - 16]      ; byte count
    mov rax, [rbp - 8]
    cmp rax, FORTH_OBJECT_RECORD_MAX
    jae .work_error
    shl rax, 7
    lea rax, [rbx + DATA_BASE_OFF + FORTH_OBJECT_RECORD_BASE * 8 + rax]
    cmp qword [rax], 1
    jne .work_error
    mov r11, [rax + 8 * 2]
    cmp r11, [rbx + WS_ELF_BASE]
    jne .work_error
    mov rcx, [rax + 8 * 3]
    cmp rcx, [rbx + WS_ELF_LEN]
    ja .work_error
    cmp r8, rcx
    ja .work_error
    sub rcx, r8
    cmp r10, rcx
    ja .work_error
    mov rcx, [rax + 8 * 8]
    cmp qword [rax + 8 * 4], 0
    je .work_error
    cmp r9, rcx
    ja .work_error
    sub rcx, r9
    cmp r10, rcx
    ja .work_error
    lea r11, [r11 + r8]
    mov r10, [rax + 8 * 4]
    add r10, r9
    mov rcx, [rbp - 16]
.ecopy_loop:
    test rcx, rcx
    jz .ecopy_done
    mov al, [r11]
    mov [r10], al
    inc r11
    inc r10
    dec rcx
    jmp .ecopy_loop
.ecopy_done:
    sub rbp, 32
    jmp .exec_loop

.op_o64store:
    call need3
    jc .underflow_error
    mov rax, [rbp - 16]
    cmp rax, FORTH_OBJECT_RECORD_MAX
    jae .work_error
    shl rax, 7
    lea rax, [rbx + DATA_BASE_OFF + FORTH_OBJECT_RECORD_BASE * 8 + rax]
    mov rdx, [rbp - 8]
    mov rcx, [rax + 8 * 4]
    test rcx, rcx
    jz .work_error
    mov r8, [rax + 8 * 8]
    cmp rdx, r8
    ja .work_error
    sub r8, rdx
    cmp r8, 8
    jb .work_error
    add rcx, rdx
    mov rax, [rbp - 24]
    mov [rcx], rax
    sub rbp, 24
    jmp .exec_loop

.op_osmap:
    call need4
    jc .underflow_error
%ifdef STANDALONE_ONLY
    jmp .op_osmap_syscall
%else
    test qword [rbx + WS_FLAGS], SYSCALL_SERVICES_FLAG
    jnz .op_osmap_syscall
    mov rax, [rbx + WS_SVC_MAP]
    test rax, rax
    jz .work_error
    mov rdi, [rbx + WS_SVC_CONTEXT]
    mov rsi, [rbp - 32]
    mov rdx, [rbp - 24]
    mov rcx, [rbp - 16]
    mov r8, [rbp - 8]
    sub rsp, 8
    call rax
    add rsp, 8
    sub rbp, 24
    mov [rbp - 8], rax
    jmp .exec_loop
%endif

.op_osmap_syscall:
    test qword [rbp - 8], 4
    jnz .osmap_new
    cmp qword [rbx + DATA_BASE_OFF + 1947 * 8], 1
    jne .osmap_new
    mov rax, [rbx + DATA_BASE_OFF + 1949 * 8]
    cmp rax, 48
    jae .osmap_new
    shl rax, 7
    lea rax, [rbx + DATA_BASE_OFF + 256 * 8 + rax]
    cmp qword [rax], 1
    jne .osmap_new
    mov rsi, [rbp - 24]
    cmp [rax + 8 * 8], rsi
    jne .osmap_new
    mov rax, [rax + 8 * 4]
    test rax, rax
    jnz .osmap_syscall_done
.osmap_new:
    mov rdi, [rbp - 32]
    mov rsi, [rbp - 24]
    test rsi, rsi
    jz .work_error
    cmp rsi, 16777216
    ja .work_error
    mov rdx, [rbp - 16]
    test rdx, ~7
    jnz .work_error
    mov r10, 0x22
    test qword [rbp - 8], 2
    jz .osmap_flags_ready
    or r10, 0x100000
.osmap_flags_ready:
    mov r8, -1
    xor r9d, r9d
    mov eax, 9
    syscall
    cmp rax, -4095
    jb .osmap_syscall_done
    xor eax, eax
.osmap_syscall_done:
    sub rbp, 24
    mov [rbp - 8], rax
    jmp .exec_loop

.op_o64fetch:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    cmp rax, FORTH_OBJECT_RECORD_MAX
    jae .work_error
    shl rax, 7
    lea rax, [rbx + DATA_BASE_OFF + FORTH_OBJECT_RECORD_BASE * 8 + rax]
    mov rdx, [rbp - 8]
    mov rcx, [rax + 8 * 8]
    cmp qword [rax + 8 * 4], 0
    je .work_error
    cmp rdx, rcx
    ja .work_error
    sub rcx, rdx
    cmp rcx, 8
    jb .work_error
    add rdx, [rax + 8 * 4]
    mov rdx, [rdx]
    sub rbp, 8
    mov [rbp - 8], rdx
    jmp .exec_loop

.op_o8fetch:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    cmp rax, FORTH_OBJECT_RECORD_MAX
    jae .work_error
    shl rax, 7
    lea rax, [rbx + DATA_BASE_OFF + FORTH_OBJECT_RECORD_BASE * 8 + rax]
    mov rdx, [rbp - 8]
    cmp qword [rax + 8 * 4], 0
    je .work_error
    cmp rdx, [rax + 8 * 8]
    jae .work_error
    add rdx, [rax + 8 * 4]
    movzx rdx, byte [rdx]
    sub rbp, 8
    mov [rbp - 8], rdx
    jmp .exec_loop

.op_ocall:
    call need2
    jc .underflow_error
    mov rax, [rbp - 16]
    cmp rax, FORTH_OBJECT_RECORD_MAX
    jae .work_error
    shl rax, 7
    lea rax, [rbx + DATA_BASE_OFF + FORTH_OBJECT_RECORD_BASE * 8 + rax]
    mov rdx, [rbp - 8]
    cmp qword [rax + 8 * 4], 0
    je .work_error
    cmp rdx, [rax + 8 * 8]
    jae .work_error
    mov r9, [rax + 8 * 7]
    shr r9, 32
    add r9, [rax + 8 * 4]
    mov r10, [rax + 8 * 6]
    shr r10, 32
    add rdx, [rax + 8 * 4]
    push rcx
    push r11
    sub rsp, 40
    mov [rsp + 16], rdx
    mov [rsp + 24], r9
    mov [rsp + 32], r10
    mov rdi, r9
    mov rsi, r10
    mov edx, 5
    mov eax, 10
    syscall
    test rax, rax
    jnz .ocall_fail
    mov qword [rsp], 0
    mov eax, 158
    mov edi, 0x1003
    mov rsi, rsp
    syscall
    test rax, rax
    jnz .ocall_fail
    mov rsi, [rbx + DATA_BASE_OFF + 1707 * 8]
    test rsi, rsi
    jz .ocall_ready
    mov eax, 158
    mov edi, 0x1002
    syscall
    test rax, rax
    jnz .ocall_fail
.ocall_ready:
    call qword [rsp + 16]
    mov [rsp + 8], rax
    mov rsi, [rsp]
    mov eax, 158
    mov edi, 0x1002
    syscall
    test rax, rax
    jnz .ocall_fail
    mov rax, [rbp - 16]
    cmp rax, [rbx + DATA_BASE_OFF + 1949 * 8]
    jbe .ocall_done
    mov rdi, [rsp + 24]
    mov rsi, [rsp + 32]
    mov edx, 3
    mov eax, 10
    syscall
    test rax, rax
    jnz .ocall_fail
.ocall_done:
    mov rax, [rsp + 8]
    add rsp, 40
    pop r11
    pop rcx
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop
.ocall_fail:
    add rsp, 40
    pop r11
    pop rcx
    jmp .work_error

.op_streq:
    call need4
    jc .underflow_error
    mov rax, [rbp - 32]
    cmp rax, FORTH_OBJECT_RECORD_MAX
    jae .work_error
    shl rax, 7
    lea rax, [rbx + DATA_BASE_OFF + FORTH_OBJECT_RECORD_BASE * 8 + rax]
    cmp qword [rax + 8 * 4], 0
    je .work_error
    mov r8, [rbp - 24]
    cmp r8, [rax + 8 * 8]
    jae .work_error
    add r8, [rax + 8 * 4]
    mov rax, [rbp - 16]
    cmp rax, FORTH_OBJECT_RECORD_MAX
    jae .work_error
    shl rax, 7
    lea rax, [rbx + DATA_BASE_OFF + FORTH_OBJECT_RECORD_BASE * 8 + rax]
    cmp qword [rax + 8 * 4], 0
    je .work_error
    mov r9, [rbp - 8]
    cmp r9, [rax + 8 * 8]
    jae .work_error
    add r9, [rax + 8 * 4]
    xor ecx, ecx
.streq_loop:
    cmp ecx, 128
    jae .streq_false
    mov dl, [r8]
    cmp dl, [r9]
    jne .streq_false
    test dl, dl
    jz .streq_true
    inc r8
    inc r9
    inc ecx
    jmp .streq_loop
.streq_true:
    mov rax, -1
    jmp .streq_done
.streq_false:
    xor eax, eax
.streq_done:
    sub rbp, 24
    mov [rbp - 8], rax
    jmp .exec_loop

.op_osunmap:
    call need2
    jc .underflow_error
%ifdef STANDALONE_ONLY
    jmp .op_osunmap_syscall
%else
    test qword [rbx + WS_FLAGS], SYSCALL_SERVICES_FLAG
    jnz .op_osunmap_syscall
    mov rax, [rbx + WS_SVC_UNMAP]
    test rax, rax
    jz .work_error
    mov rdi, [rbx + WS_SVC_CONTEXT]
    mov rsi, [rbp - 16]
    mov rdx, [rbp - 8]
    xor ecx, ecx
    xor r8d, r8d
    sub rsp, 8
    call rax
    add rsp, 8
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop
%endif

.op_osunmap_syscall:
    mov rdi, [rbp - 16]
    mov rsi, [rbp - 8]
    mov eax, 11
    syscall
    sub rbp, 8
    mov [rbp - 8], rax
    jmp .exec_loop

.op_osprotect:
    call need3
    jc .underflow_error
%ifdef STANDALONE_ONLY
    jmp .op_osprotect_syscall
%else
    test qword [rbx + WS_FLAGS], SYSCALL_SERVICES_FLAG
    jnz .op_osprotect_syscall
    mov rax, [rbx + WS_SVC_PROTECT]
    test rax, rax
    jz .work_error
    mov rdi, [rbx + WS_SVC_CONTEXT]
    mov rsi, [rbp - 24]
    mov rdx, [rbp - 16]
    mov rcx, [rbp - 8]
    xor r8d, r8d
    sub rsp, 8
    call rax
    add rsp, 8
    sub rbp, 16
    mov [rbp - 8], rax
    jmp .exec_loop
%endif

.op_osprotect_syscall:
    mov rdi, [rbp - 24]
    mov rsi, [rbp - 16]
    mov rdx, [rbp - 8]
    test rdx, ~7
    jnz .work_error
    mov eax, 10
    syscall
    sub rbp, 16
    mov [rbp - 8], rax
    jmp .exec_loop

.op_oscopy:
    call need3
    jc .underflow_error
%ifdef STANDALONE_ONLY
    jmp .op_oscopy_internal
%else
    test qword [rbx + WS_FLAGS], SYSCALL_SERVICES_FLAG
    jnz .op_oscopy_internal
    mov rax, [rbx + WS_SVC_COPY]
    test rax, rax
    jz .work_error
    mov rdi, [rbx + WS_SVC_CONTEXT]
    mov rsi, [rbp - 24]
    mov rdx, [rbp - 16]
    mov rcx, [rbp - 8]
    xor r8d, r8d
    sub rsp, 8
    call rax
    add rsp, 8
    sub rbp, 16
    mov [rbp - 8], rax
    jmp .exec_loop
%endif

.op_oscopy_internal:
    mov rdi, [rbp - 24]
    mov rsi, [rbp - 16]
    mov rcx, [rbp - 8]
.oscopy_internal_loop:
    test rcx, rcx
    jz .oscopy_internal_done
    mov al, [rdi]
    mov [rsi], al
    inc rdi
    inc rsi
    dec rcx
    jmp .oscopy_internal_loop
.oscopy_internal_done:
    sub rbp, 16
    mov qword [rbp - 8], 0
    jmp .exec_loop

.op_cpuid:
    call need2
    jc .underflow_error
    lea rdx, [rbx + WS_HDR_SIZE + STACK_SIZE - LOOP_STATE_SIZE]
    lea rax, [rbp + 16]
    cmp rax, rdx
    ja .work_error
    mov eax, [rbp - 16]
    mov ecx, [rbp - 8]
    push rbx
    cpuid
    mov r8d, eax
    mov r9d, ebx
    mov r10d, ecx
    mov r11d, edx
    pop rbx
    mov [rbp - 16], r8
    mov [rbp - 8], r9
    mov [rbp], r10
    mov [rbp + 8], r11
    add rbp, 16
    call record_depth
    jmp .exec_loop

.op_osread:
    call need4
    jc .underflow_error
%ifdef STANDALONE_ONLY
    jmp .op_osread_syscall
%else
    test qword [rbx + WS_FLAGS], SYSCALL_SERVICES_FLAG
    jnz .op_osread_syscall
    mov rax, [rbx + WS_SVC_READ_FILE]
    test rax, rax
    jz .work_error
    mov rdi, [rbx + WS_SVC_CONTEXT]
    mov rsi, [rbp - 32]
    mov rdx, [rbp - 24]
    mov rcx, [rbp - 16]
    mov r8, [rbp - 8]
    sub rsp, 8
    call rax
    add rsp, 8
    sub rbp, 24
    mov [rbp - 8], rax
    jmp .exec_loop
%endif

.op_osread_syscall:
    mov rdi, [rbp - 32]      ; NUL-terminated pathname
    mov rax, [rbp - 24]
    test rax, rax
    jz .work_error
    cmp rax, 4095
    ja .work_error
    mov r11, [rbp - 16]      ; source slot
    cmp r11, 48
    jae .work_error
    mov rax, [rbp - 8]       ; capacity
    test rax, rax
    jz .work_error
    cmp rax, 16777216
    ja .work_error
    push r12
    push r13
    push r14
    push r15
    mov eax, 257             ; openat(AT_FDCWD, path, O_RDONLY, 0)
    mov edi, -100
    mov rsi, [rbp - 32]
    xor edx, edx
    xor r10d, r10d
    syscall
    cmp rax, -4095
    jae .osread_error
    mov r12, rax             ; fd (callee-saved VM input-end is no longer needed)
    sub rsp, 160             ; struct stat scratch
    mov eax, 5               ; fstat
    mov rdi, r12
    mov rsi, rsp
    syscall
    cmp rax, -4095
    jae .osread_stat_error
    mov r13, [rsp]           ; device
    mov r14, [rsp + 8]       ; inode
    mov rcx, [rsp + 48]      ; size
    test rcx, rcx
    jz .osread_size_error
    test rcx, rcx
    js .osread_size_error
    cmp rcx, [rbp - 8]
    ja .osread_size_error
    ; Deduplicate already ingested objects by the kernel identity.
    xor r8d, r8d
.osread_dedup_loop:
    cmp r8, 48
    jae .osread_allocate
    mov rax, r8
    shl rax, 7
    lea rdx, [rbx + DATA_BASE_OFF + 256 * 8 + rax]
    cmp qword [rdx + 8], 2
    jne .osread_dedup_next
    mov rax, [rdx + 16]
    test rax, rax
    jz .osread_dedup_next
    cmp [rax - 16], r13
    jne .osread_dedup_next
    cmp [rax - 8], r14
    jne .osread_dedup_next
    mov eax, 3
    mov rdi, r12
    syscall
    mov rax, r8
    inc rax
    shl rax, 32
    mov edx, -1
    or rax, rdx
    add rsp, 160
    pop r15
    pop r14
    pop r13
    pop r12
    sub rbp, 24
    mov [rbp - 8], rax
    jmp .exec_loop
.osread_dedup_next:
    inc r8
    jmp .osread_dedup_loop
.osread_allocate:
    mov r15, rcx             ; exact size
    add rcx, 16
    jc .osread_size_error
    mov rsi, rcx
    xor edi, edi
    mov edx, 3
    mov r10d, 0x22
    mov r8, -1
    xor r9d, r9d
    mov eax, 9
    syscall
    cmp rax, -4095
    jae .osread_stat_error
    mov [rax], r13
    mov [rax + 8], r14
    lea r13, [rax + 16]      ; source bytes
    xor r14d, r14d           ; bytes read
.osread_loop:
    cmp r14, r15
    jae .osread_complete
    xor eax, eax             ; read
    mov rdi, r12
    lea rsi, [r13 + r14]
    mov rdx, r15
    sub rdx, r14
    syscall
    cmp rax, -4
    je .osread_loop
    test rax, rax
    jle .osread_read_error
    add r14, rax
    jmp .osread_loop
.osread_complete:
    mov rax, [rbp - 16]
    shl rax, 7
    lea rdx, [rbx + DATA_BASE_OFF + 256 * 8 + rax]
    mov qword [rdx + 8], 2
    mov [rdx + 16], r13
    mov [rdx + 24], r15
    mov eax, 3
    mov rdi, r12
    syscall
    mov rax, [rbp - 16]
    inc rax
    shl rax, 32
    mov edx, -1
    or rax, rdx
    add rsp, 160
    pop r15
    pop r14
    pop r13
    pop r12
    sub rbp, 24
    mov [rbp - 8], rax
    jmp .exec_loop
.osread_read_error:
    mov r10, rax
    lea rdi, [r13 - 16]
    lea rsi, [r15 + 16]
    mov eax, 11
    syscall
    mov rax, r10
    jmp .osread_stat_error_close
.osread_size_error:
    mov rax, -27             ; EFBIG
.osread_stat_error_close:
    push rax
    mov eax, 3
    mov rdi, r12
    syscall
    pop rax
    add rsp, 160
    jmp .osread_finish_error
.osread_stat_error:
    push rax
    mov eax, 3
    mov rdi, r12
    syscall
    pop rax
    add rsp, 160
    jmp .osread_finish_error
.osread_error:
.osread_finish_error:
    pop r15
    pop r14
    pop r13
    pop r12
    sub rbp, 24
    mov [rbp - 8], rax
    jmp .exec_loop

.op_osclose:
    call need1
    jc .underflow_error
%ifdef STANDALONE_ONLY
    jmp .op_osclose_syscall
%else
    test qword [rbx + WS_FLAGS], SYSCALL_SERVICES_FLAG
    jnz .op_osclose_syscall
    mov rax, [rbx + WS_SVC_CLOSE]
    test rax, rax
    jz .work_error
    mov rdi, [rbx + WS_SVC_CONTEXT]
    mov rsi, [rbp - 8]
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    sub rsp, 8
    call rax
    add rsp, 8
    mov [rbp - 8], rax
    jmp .exec_loop
%endif

.op_osclose_syscall:
    mov rdi, [rbp - 8]
    mov eax, 3
    syscall
    mov [rbp - 8], rax
    jmp .exec_loop

.op_pbase:
    call ensure_push
    jc .work_error
    lea rax, [rbx + PATH_BUFFER_BASE_OFF]
    mov [rbp], rax
    add rbp, 8
    call record_depth
    jmp .exec_loop

.op_p8fetch:
    call need1
    jc .underflow_error
    mov rax, [rbp - 8]
    cmp rax, PATH_BUFFER_SIZE
    jae .work_error
    movzx rax, byte [rbx + PATH_BUFFER_BASE_OFF + rax]
    mov [rbp - 8], rax
    jmp .exec_loop

.op_p8store:
    call need2
    jc .underflow_error
    mov rax, [rbp - 8]
    cmp rax, PATH_BUFFER_SIZE
    jae .work_error
    mov rdx, [rbp - 16]
    mov [rbx + PATH_BUFFER_BASE_OFF + rax], dl
    sub rbp, 16
    jmp .exec_loop

.op_esource:
    call need1
    jc .underflow_error
    mov rax, [rbp - 8]
    cmp rax, FORTH_OBJECT_RECORD_MAX
    jae .work_error
    shl rax, 7
    lea rax, [rbx + DATA_BASE_OFF + FORTH_OBJECT_RECORD_BASE * 8 + rax]
    cmp qword [rax + 8 * 1], 0
    je .work_error
    mov rdx, [rax + 8 * 2]
    test rdx, rdx
    jz .work_error
    mov rcx, [rax + 8 * 3]
    test rcx, rcx
    jz .work_error
    cmp rcx, FORTH_SOURCE_SIZE_MAX
    ja .work_error
    mov [rbx + WS_ELF_BASE], rdx
    mov [rbx + WS_ELF_LEN], rcx
    sub rbp, 8
    jmp .exec_loop

.success:
    mov rax, r13
    sub rax, [rbx + WS_OUTBASE]
    mov [rbx + WS_STATUS], rax
    mov rdx, rbp
    lea rcx, [rbx + WS_HDR_SIZE]
    sub rdx, rcx
    shr rdx, 3
    mov [rbx + WS_FINAL_DEPTH], rdx
    jmp .ret

.compile_only_success:
    xor rax, rax
    mov [rbx + WS_STATUS], rax
    jmp .ret

.unknown_error:
    mov rax, ERR_UNKNOWN
    jmp .fail
.underflow_error:
    mov rax, ERR_UNDERFLOW
    jmp .fail
.badnum_error:
    mov rax, ERR_BADNUM
    jmp .fail
.out_error:
    mov rax, ERR_OUT
    jmp .fail
.work_error:
    mov rax, ERR_WORK
    jmp .fail
.divzero_error:
    mov rax, ERR_DIVZERO
.fail:
    mov [rbx + WS_STATUS], rax
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

%ifndef PACKED_LOADER
skip_ws:
    cmp r15, r14
    jae .done
    mov al, [r15]
    cmp al, ' '
    je .skip
    cmp al, 9
    je .skip
    cmp al, 10
    je .skip
    cmp al, 13
    je .skip
    ret
.skip:
    inc r15
    jmp skip_ws
.done:
    ret

scan_token:
    mov rdi, r15
.loop:
    cmp r15, r14
    jae .done
    mov al, [r15]
    cmp al, ' '
    je .done
    cmp al, 9
    je .done
    cmp al, 10
    je .done
    cmp al, 13
    je .done
    inc r15
    jmp .loop
.done:
    mov rsi, r15
    sub rsi, rdi
    ret

emit_orig_token:
    ; rax=op, rdx=imm
    lea rcx, [r11 + 16]
    cmp rcx, r10
    ja .fail
    mov [r11], rax
    mov [r11 + 8], rdx
    mov r11, rcx
    inc qword [rbx + WS_ORIG]
    clc
    ret
.fail:
    stc
    ret
%endif

emit_xform_token:
    ; rax=op, rdx=imm
    lea rcx, [r11 + 16]
    cmp rcx, r10
    ja .fail
    mov [r11], rax
    mov [r11 + 8], rdx
    mov r11, rcx
    inc qword [rbx + WS_XTOK]
    clc
    ret
.fail:
    stc
    ret

%ifndef PACKED_LOADER
compile_number:
    ; rdx=number
    mov rax, OP_LIT
    call emit_orig_token
    jc .err
    ret
.err:
    jmp forth_entry.work_error

compile_for:
    ; Forth syntax: <count> for ... i ... next.
    ; Stores relative token offsets so copied source remains position independent.
    mov r8, [rbx + CTRL_DEPTH_OFF]
    cmp r8, CTRL_LIMIT
    jae .bad
    mov r9, [rbx + WS_ORIG]
    mov rax, OP_FOR
    xor rdx, rdx
    call emit_orig_token
    jc .bad
    lea rcx, [rbx + CTRL_BASE_OFF]
    shl r8, 5
    mov [rcx + r8], r9
    mov qword [rcx + r8 + 8], CTRL_FOR
    lea rax, [r11 - 8]
    mov [rcx + r8 + 16], rax
    inc qword [rbx + CTRL_DEPTH_OFF]
    clc
    ret
.bad:
    stc
    ret

compile_next:
    push r12
    mov r8, [rbx + CTRL_DEPTH_OFF]
    test r8, r8
    jz .bad
    dec r8
    mov [rbx + CTRL_DEPTH_OFF], r8
    lea rcx, [rbx + CTRL_BASE_OFF]
    shl r8, 5
    cmp qword [rcx + r8 + 8], CTRL_FOR
    jne .bad
    mov r9, [rcx + r8]           ; matching for token index
    mov r12, [rbx + WS_ORIG]     ; next token index

    mov rdx, r9
    sub rdx, r12                 ; next jumps back to first body token
    mov rax, OP_NEXT
    call emit_orig_token
    jc .bad

    mov rax, r12
    sub rax, r9                  ; for skips body and next when count <= 0
    lea rcx, [rbx + CTRL_BASE_OFF]
    mov rcx, [rcx + r8 + 16]
    mov [rcx], rax
    pop r12
    clc
    ret
.bad:
    pop r12
    stc
    ret

compile_if:
    ; Forth syntax: flag if ... else ... then. else is optional.
    mov r8, [rbx + CTRL_DEPTH_OFF]
    cmp r8, CTRL_LIMIT
    jae .bad
    mov r9, [rbx + WS_ORIG]
    mov rax, OP_BRZ
    xor rdx, rdx
    call emit_orig_token
    jc .bad
    lea rcx, [rbx + CTRL_BASE_OFF]
    shl r8, 5
    mov [rcx + r8], r9
    mov qword [rcx + r8 + 8], CTRL_IF
    lea rax, [r11 - 8]
    mov [rcx + r8 + 16], rax
    inc qword [rbx + CTRL_DEPTH_OFF]
    clc
    ret
.bad:
    stc
    ret

compile_else:
    push r12
    mov r8, [rbx + CTRL_DEPTH_OFF]
    test r8, r8
    jz .bad
    dec r8
    lea rcx, [rbx + CTRL_BASE_OFF]
    shl r8, 5
    cmp qword [rcx + r8 + 8], CTRL_IF
    jne .bad
    mov r9, [rcx + r8]           ; matching if token index
    mov r12, [rbx + WS_ORIG]     ; else branch token index

    mov rax, OP_BR
    xor rdx, rdx
    call emit_orig_token
    jc .bad

    lea rcx, [rbx + CTRL_BASE_OFF]
    mov rax, r12
    sub rax, r9                  ; false branch starts after the else branch token
    mov rdx, [rcx + r8 + 16]
    mov [rdx], rax

    mov [rcx + r8], r12
    mov qword [rcx + r8 + 8], CTRL_ELSE
    lea rax, [r11 - 8]
    mov [rcx + r8 + 16], rax
    pop r12
    clc
    ret
.bad:
    pop r12
    stc
    ret

compile_then:
    push r12
    mov r8, [rbx + CTRL_DEPTH_OFF]
    test r8, r8
    jz .bad
    dec r8
    mov [rbx + CTRL_DEPTH_OFF], r8
    lea rcx, [rbx + CTRL_BASE_OFF]
    shl r8, 5
    mov r9, [rcx + r8]           ; matching if/else token index
    mov r12, [rbx + WS_ORIG]     ; then marker token index

    mov rax, OP_THEN
    xor rdx, rdx
    call emit_orig_token
    jc .bad

    lea rcx, [rbx + CTRL_BASE_OFF]
    mov rax, [rcx + r8 + 8]
    cmp rax, CTRL_IF
    je .patch_if
    cmp rax, CTRL_ELSE
    jne .bad
.patch_else:
    mov rax, r12
    sub rax, r9
    jmp .write_patch
.patch_if:
    mov rax, r12
    sub rax, r9                  ; false branch skips to after then marker
.write_patch:
    mov rdx, [rcx + r8 + 16]
    mov [rdx], rax
    pop r12
    clc
    ret
.bad:
    pop r12
    stc
    ret

maybe_insert_noop:
%endif
maybe_insert_noop:
    call next_rand
    and rax, 3
    cmp rax, 0
    jne .done
    mov rax, OP_LIT
    xor rdx, rdx
    call emit_xform_token
    jc .done
    mov rax, OP_DROP
    xor rdx, rdx
    call emit_xform_token
    jc .done
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_NOOP
    mov rdx, OP_DROP
    xor r8, r8
    mov r9, 2
    call record_trace
.done:
    ret

%ifndef PACKED_LOADER
try_word:
    ; rdi=token ptr, rsi=len. CF clear on compiled, set if no word.
    cmp rsi, 1
    je .len1
    cmp rsi, 2
    je .len2
    cmp rsi, 3
    je .len3
    cmp rsi, 4
    je .len4
    cmp rsi, 5
    je .len5
    cmp rsi, 6
    je .len6
    cmp rsi, 7
    je .len7
    cmp rsi, 8
    je .len8
    cmp rsi, 9
    je .len9
    jmp .no
.len1:
    mov al, [rdi]
    cmp al, '+'
    je .add
    cmp al, '-'
    je .sub
    cmp al, '*'
    je .mul
    cmp al, '='
    je .eq
    cmp al, '<'
    je .lt
    cmp al, '>'
    je .gt
    cmp al, '.'
    je .dot
    cmp al, ':'
    je .colon
    cmp al, 'i'
    je .loop_i
    jmp .no
.len2:
    cmp byte [rdi], '0'
    jne .not_zeroeq
    cmp byte [rdi + 1], '='
    je .zeroeq
    jmp .no
.not_zeroeq:
    cmp byte [rdi], '1'
    jne .not_one
    cmp byte [rdi + 1], '+'
    je .oneplus
    cmp byte [rdi + 1], '-'
    je .oneminus
    jmp .no
.not_one:
    cmp byte [rdi], '2'
    jne .not_twomul
    cmp byte [rdi + 1], '*'
    je .twomul
    jmp .no
.not_twomul:
    cmp byte [rdi], 'i'
    jne .not_if
    cmp byte [rdi + 1], 'f'
    je .if
.not_if:
    cmp byte [rdi], 'm'
    jne .not_mem
    cmp byte [rdi + 1], '@'
    je .mfetch
    cmp byte [rdi + 1], '!'
    je .mstore
    jmp .no
.not_mem:
    cmp byte [rdi], 'u'
    jne .not_u8
    cmp byte [rdi + 1], '8'
    je .u8
    jmp .not_u8
.not_u8:
    cmp byte [rdi], 'u'
    jne .not_ucmp
    cmp byte [rdi + 1], '<'
    je .ult
    cmp byte [rdi + 1], '>'
    je .ugt
    cmp byte [rdi + 1], '/'
    je .udiv
    jmp .no
.not_ucmp:
    cmp byte [rdi], 'o'
    jne .not_or
    cmp byte [rdi + 1], 'r'
    je .or
    jmp .no
.not_or:
    cmp byte [rdi], 'c'
    jne .no
    cmp byte [rdi + 1], 'r'
    je .cr
    jmp .no
.len3:
    cmp byte [rdi], 'i'
    jne .not_image8
    cmp byte [rdi + 1], '8'
    jne .not_image8
    cmp byte [rdi + 2], '@'
    je .i8fetch
    cmp byte [rdi + 2], '!'
    je .i8store
    jmp .no
.not_image8:
    cmp byte [rdi], 'o'
    jne .not_object8
    cmp byte [rdi + 1], '8'
    jne .not_object8
    cmp byte [rdi + 2], '@'
    je .o8fetch
.not_object8:
    cmp byte [rdi], 'p'
    jne .not_path8
    cmp byte [rdi + 1], '8'
    jne .not_path8
    cmp byte [rdi + 2], '@'
    je .p8fetch
    cmp byte [rdi + 2], '!'
    je .p8store
.not_path8:
    cmp byte [rdi], 'u'
    jne .not_u_word
    cmp byte [rdi + 1], '1'
    jne .not_u16
    cmp byte [rdi + 2], '6'
    je .u16
.not_u16:
    cmp byte [rdi + 1], '3'
    jne .not_u32
    cmp byte [rdi + 2], '2'
    je .u32
.not_u32:
    cmp byte [rdi + 1], '6'
    jne .no
    cmp byte [rdi + 2], '4'
    je .u64
    jmp .no
.not_u_word:
    cmp word [rdi], 0x6e61 ; an
    jne .not_and
    cmp byte [rdi + 2], 'd'
    je .and
.not_and:
    cmp word [rdi], 0x6f78 ; xo
    jne .not_xor
    cmp byte [rdi + 2], 'r'
    je .xor
.not_xor:
    cmp word [rdi], 0x6f66 ; fo
    jne .not_for
    cmp byte [rdi + 2], 'r'
    je .for
.not_for:
    cmp word [rdi], 0x696d ; mi
    jne .not_min
    cmp byte [rdi + 2], 'n'
    je .min
.not_min:
    cmp word [rdi], 0x616d ; ma
    jne .not_max
    cmp byte [rdi + 2], 'x'
    je .max
.not_max:
    cmp byte [rdi], 'd'
    jne .no
    cmp byte [rdi + 1], 'u'
    jne .no
    cmp byte [rdi + 2], 'p'
    je .dup
    jmp .no
.len4:
    cmp dword [rdi], 0x6c6c6563 ; cell
    je .cell
    cmp dword [rdi], 0x2134366f ; o64!
    je .o64store
    cmp dword [rdi], 0x4034366f ; o64@
    je .o64fetch
    cmp dword [rdi], 0x40343669 ; i64@
    je .i64fetch
    cmp dword [rdi], 0x21343669 ; i64!
    je .i64store
    cmp dword [rdi], 0x65736c65 ; else
    je .else
    cmp dword [rdi], 0x6e656874 ; then
    je .then
    cmp dword [rdi], 0x6e656c65 ; elen
    je .elen
    cmp dword [rdi], 0x706f7264 ; drop
    je .drop
    cmp dword [rdi], 0x70617773 ; swap
    je .swap
    cmp dword [rdi], 0x7265766f ; over
    je .over
    cmp dword [rdi], 0x74696d65 ; emit
    je .emit
    cmp dword [rdi], 0x7478656e ; next
    je .next
    jmp .no
.len5:
    cmp dword [rdi], 0x61727261 ; arra
    jne .not_array
    cmp byte [rdi + 4], 'y'
    je .array
.not_array:
    cmp dword [rdi], 0x6c656966 ; fiel
    jne .not_field
    cmp byte [rdi + 4], 'd'
    je .field
.not_field:
    cmp dword [rdi], 0x74646977 ; widt
    jne .not_width
    cmp byte [rdi + 4], 'h'
    je .width
.not_width:
    cmp dword [rdi], 0x6f696e75 ; unio
    jne .not_union
    cmp byte [rdi + 4], 'n'
    je .union
.not_union:
    cmp dword [rdi], 0x6c61636e ; ncal
    jne .not_ncall
    cmp byte [rdi + 4], 'l'
    je .ocall
.not_ncall:
    cmp dword [rdi], 0x69757063 ; cpui
    jne .not_cpuid
    cmp byte [rdi + 4], 'd'
    je .cpuid
.not_cpuid:
    cmp dword [rdi], 0x73616270 ; pbas
    jne .not_pbase
    cmp byte [rdi + 4], 'e'
    je .pbase
.not_pbase:
    cmp dword [rdi], 0x616d736f ; osma
    jne .not_osmap
    cmp byte [rdi + 4], 'p'
    je .osmap
.not_osmap:
    cmp dword [rdi], 0x6c61636f ; ocal
    jne .not_ocall
    cmp byte [rdi + 4], 'l'
    je .ocall
.not_ocall:
    cmp dword [rdi], 0x65727473 ; stre
    jne .not_streq
    cmp byte [rdi + 4], 'q'
    je .streq
.not_streq:
    cmp dword [rdi], 0x706f6365 ; ecop
    jne .not_ecopy
    cmp byte [rdi + 4], 'y'
    je .ecopy
.not_ecopy:
    cmp dword [rdi], 0x73616265 ; ebas
    jne .no
    cmp byte [rdi + 4], 'e'
    je .ebase
    jmp .no
.len6:
    cmp dword [rdi], 0x6f79616c ; layo
    jne .not_layout
    cmp word [rdi + 4], 0x7475 ; ut
    je .layout
.not_layout:
    cmp dword [rdi], 0x6c656966 ; fiel
    jne .not_fields
    cmp word [rdi + 4], 0x7364 ; ds
    je .fields
.not_fields:
    cmp dword [rdi], 0x626f6c62 ; blob
    jne .not_blob64
    cmp word [rdi + 4], 0x3436 ; 64
    je .blob64
.not_blob64:
    cmp dword [rdi], 0x6f63736f ; osco
    jne .not_oscopy
    cmp word [rdi + 4], 0x7970 ; py
    je .oscopy
.not_oscopy:
    cmp dword [rdi], 0x7270736f ; ospr
    jne .not_osprotect
    cmp word [rdi + 4], 0x746f ; ot
    je .osprotect
.not_osprotect:
    cmp dword [rdi], 0x6572736f ; osre
    jne .not_osread
    cmp word [rdi + 4], 0x6461 ; ad
    je .osread
.not_osread:
    cmp dword [rdi], 0x6968736c ; lshi
    jne .not_lshift
    cmp word [rdi + 4], 0x7466 ; ft
    je .lshift
    jmp .no
.not_lshift:
    cmp dword [rdi], 0x69687372 ; rshi
    jne .not_rshift
    cmp word [rdi + 4], 0x7466 ; ft
    je .rshift
    jmp .no
.not_rshift:
    cmp dword [rdi], 0x6167656e ; nega
    jne .not_neg
    cmp word [rdi + 4], 0x6574 ; te
    je .neg
    jmp .no
.not_neg:
    cmp dword [rdi], 0x65766e69 ; inve
    jne .no
    cmp word [rdi + 4], 0x7472 ; rt
    je .invert
    jmp .no
.len7:
    cmp dword [rdi], 0x6f636572 ; reco
    jne .not_records
    cmp word [rdi + 4], 0x6472 ; rd
    jne .not_records
    cmp byte [rdi + 6], 's'
    je .records
.not_records:
    cmp dword [rdi], 0x756f7365 ; esou
    jne .not_esource
    cmp word [rdi + 4], 0x6372 ; rc
    jne .not_esource
    cmp byte [rdi + 6], 'e'
    je .esource
.not_esource:
    cmp dword [rdi], 0x6e75736f ; osun
    jne .not_osunmap
    cmp word [rdi + 4], 0x616d ; ma
    jne .not_osunmap
    cmp byte [rdi + 6], 'p'
    je .osunmap
.not_osunmap:
    cmp dword [rdi], 0x6c63736f ; oscl
    jne .not_osclose
    cmp word [rdi + 4], 0x736f ; os
    jne .not_osclose
    cmp byte [rdi + 6], 'e'
    je .osclose
.not_osclose:
    jmp .no
.len8:
    cmp dword [rdi], 0x736e6f63 ; cons
    jne .not_constant
    cmp dword [rdi + 4], 0x746e6174 ; tant
    je .constant
.not_constant:
    cmp dword [rdi], 0x63737973 ; sysc
    jne .not_syscall6
    cmp dword [rdi + 4], 0x366c6c61 ; all6
    je .syscall6
.not_syscall6:
    jmp .no
.len9:
    jmp .no
.no:
    call find_constant
    jnc .const_found
    call expand_inline_word
    jnc .inline_found
    stc
    ret
.const_found:
    mov rdx, rax
    mov rax, OP_LIT
    call emit_orig_token
    ret
.inline_found:
    ret
.dup:
    mov rax, OP_DUP
    jmp .emit0
.drop:
    mov rax, OP_DROP
    jmp .emit0
.swap:
    mov rax, OP_SWAP
    jmp .emit0
.over:
    mov rax, OP_OVER
    jmp .emit0
.add:
    mov rax, OP_ADD
    jmp .emit0
.sub:
    mov rax, OP_SUB
    jmp .emit0
.mul:
    mov rax, OP_MUL
    jmp .emit0
.eq:
    mov rax, OP_EQ
    jmp .emit0
.lt:
    mov rax, OP_LT
    jmp .emit0
.gt:
    mov rax, OP_GT
    jmp .emit0
.dot:
    mov rax, OP_DOT
    jmp .emit0
.emit:
    mov rax, OP_EMIT
    jmp .emit0
.cr:
    mov rax, OP_CR
    jmp .emit0
.neg:
    mov rax, OP_NEG
    jmp .emit0
.zeroeq:
    mov rax, OP_ZEROEQ
    jmp .emit0
.oneplus:
    mov rax, OP_ONEPLUS
    jmp .emit0
.oneminus:
    mov rax, OP_ONEMINUS
    jmp .emit0
.invert:
    mov rax, OP_INVERT
    jmp .emit0
.twomul:
    mov rax, OP_2MUL
    jmp .emit0
.and:
    mov rax, OP_AND
    jmp .emit0
.or:
    mov rax, OP_OR
    jmp .emit0
.xor:
    mov rax, OP_XOR
    jmp .emit0
.lshift:
    mov rax, OP_LSHIFT
    jmp .emit0
.rshift:
    mov rax, OP_RSHIFT
    jmp .emit0
.ult:
    mov rax, OP_ULT
    jmp .emit0
.ugt:
    mov rax, OP_UGT
    jmp .emit0
.min:
    mov rax, OP_MIN
    jmp .emit0
.max:
    mov rax, OP_MAX
    jmp .emit0
.constant:
    call define_constant
    ret
.layout:
    call define_layout_start
    ret
.union:
    call define_layout_union
    ret
.cell:
    call define_layout_cell
    ret
.array:
    call define_layout_array
    ret
.fields:
    call define_layout_fields
    ret
.field:
    call define_layout_field
    ret
.width:
    call define_layout_width
    ret
.records:
    call define_layout_records
    ret
.colon:
    call define_callable_word
    ret
.for:
    call compile_for
    ret
.loop_i:
    mov rax, OP_I
    jmp .emit0
.next:
    call compile_next
    ret
.if:
    call compile_if
    ret
.else:
    call compile_else
    ret
.then:
    call compile_then
    ret
.i8fetch:
    mov rax, OP_I8FETCH
    jmp .emit0
.i8store:
    mov rax, OP_I8STORE
    jmp .emit0
.i64fetch:
    mov rax, OP_I64FETCH
    jmp .emit0
.i64store:
    mov rax, OP_I64STORE
    jmp .emit0
.ecopy:
    mov rax, OP_ECOPY
    jmp .emit0
.o64store:
    mov rax, OP_O64STORE
    jmp .emit0
.osmap:
    mov rax, OP_OSMAP
    jmp .emit0
.o64fetch:
    mov rax, OP_O64FETCH
    jmp .emit0
.o8fetch:
    mov rax, OP_O8FETCH
    jmp .emit0
.osunmap:
    mov rax, OP_OSUNMAP
    jmp .emit0
.osprotect:
    mov rax, OP_OSPROTECT
    jmp .emit0
.osread:
    mov rax, OP_OSREAD
    jmp .emit0
.osclose:
    mov rax, OP_OSCLOSE
    jmp .emit0
.pbase:
    mov rax, OP_PBASE
    jmp .emit0
.p8fetch:
    mov rax, OP_P8FETCH
    jmp .emit0
.p8store:
    mov rax, OP_P8STORE
    jmp .emit0
.esource:
    mov rax, OP_ESOURCE
    jmp .emit0
.ocall:
    mov rax, OP_OCALL
    jmp .emit0
.streq:
    mov rax, OP_STREQ
    jmp .emit0
.oscopy:
    mov rax, OP_OSCOPY
    jmp .emit0
.cpuid:
    mov rax, OP_CPUID
    jmp .emit0
.syscall6:
    mov rax, OP_SYSCALL6
    jmp .emit0
.blob64:
    mov rax, OP_BLOB64
    jmp .emit0
.mfetch:
    mov rax, OP_MFETCH
    jmp .emit0
.mstore:
    mov rax, OP_MSTORE
    jmp .emit0
.udiv:
    mov rax, OP_UDIV
    jmp .emit0
.ebase:
    mov rax, OP_EBASE
    jmp .emit0
.elen:
    mov rax, OP_ELEN
    jmp .emit0
.u8:
    mov rax, OP_U8
    jmp .emit0
.u16:
    mov rax, OP_U16
    jmp .emit0
.u32:
    mov rax, OP_U32
    jmp .emit0
.u64:
    mov rax, OP_U64
    jmp .emit0
.emit0:
    xor rdx, rdx
    call emit_orig_token
    ret

parse_number:
    ; rdi=ptr, rsi=len. Returns rax=rdx=value, CF set on invalid.
    test rsi, rsi
    jz .bad
    xor rax, rax
    xor r8, r8
    xor r9, r9
    cmp byte [rdi], '-'
    jne .digits
    mov r9, 1
    inc r8
    cmp r8, rsi
    jae .bad
.digits:
    cmp r8, rsi
    jae .finish
    mov dl, [rdi + r8]
    cmp dl, '0'
    jb .bad
    cmp dl, '9'
    ja .bad
    imul rax, rax, 10
    sub dl, '0'
    movzx rdx, dl
    add rax, rdx
    inc r8
    jmp .digits
.finish:
    test r9, r9
    jz .ok
    neg rax
.ok:
    mov rdx, rax
    clc
    ret
.bad:
    stc
    ret
%endif

next_rand:
    mov rax, [rbx + WS_SEED]
    test rax, rax
    jnz .go
    mov rax, 0x9e3779b97f4a7c15
.go:
    mov rdx, rax
    shl rdx, 13
    xor rax, rdx
    mov rdx, rax
    shr rdx, 7
    xor rax, rdx
    mov rdx, rax
    shl rdx, 17
    xor rax, rdx
    mov [rbx + WS_SEED], rax
    ret

need1:
    lea rax, [rbx + WS_HDR_SIZE + 8]
    cmp rbp, rax
    jb .bad
    clc
    ret
.bad:
    stc
    ret

need2:
    lea rax, [rbx + WS_HDR_SIZE + 16]
    cmp rbp, rax
    jb .bad
    clc
    ret
.bad:
    stc
    ret

need3:
    lea rax, [rbx + WS_HDR_SIZE + 24]
    cmp rbp, rax
    jb .bad
    clc
    ret
.bad:
    stc
    ret

need4:
    lea rax, [rbx + WS_HDR_SIZE + 32]
    cmp rbp, rax
    jb .bad
    clc
    ret
.bad:
    stc
    ret

push_rax:
    push rax
    call ensure_push
    jc .bad
    pop rax
    mov [rbp], rax
    add rbp, 8
    call record_depth
    clc
    ret
.bad:
    pop rax
    stc
    ret

pop_elf_offset:
    call need1
    jc .bad
    sub rbp, 8
    mov rdx, [rbp]
    clc
    ret
.bad:
    stc
    ret

check_elf_bounds:
    cmp qword [rbx + WS_ELF_BASE], 0
    je .bad
    mov rax, [rbx + WS_ELF_LEN]
    cmp rax, rcx
    jb .bad
    sub rax, rcx
    cmp rdx, rax
    ja .bad
    clc
    ret
.bad:
    stc
    ret

check_image_bounds:
    mov rax, IMAGE_SIZE
    cmp rax, rcx
    jb .bad
    sub rax, rcx
    cmp rdx, rax
    ja .bad
    clc
    ret
.bad:
    stc
    ret

read_elf_u8:
    call check_elf_bounds
    jc .bad
    mov rax, [rbx + WS_ELF_BASE]
    movzx rax, byte [rax + rdx]
    clc
    ret
.bad:
    stc
    ret

read_elf_u16:
    call check_elf_bounds
    jc .bad
    mov rax, [rbx + WS_ELF_BASE]
    movzx rax, word [rax + rdx]
    clc
    ret
.bad:
    stc
    ret

read_elf_u32:
    call check_elf_bounds
    jc .bad
    mov rax, [rbx + WS_ELF_BASE]
    mov eax, dword [rax + rdx]
    clc
    ret
.bad:
    stc
    ret

read_elf_u64:
    call check_elf_bounds
    jc .bad
    mov rax, [rbx + WS_ELF_BASE]
    mov rax, [rax + rdx]
    clc
    ret
.bad:
    stc
    ret

read_elf_any:
    cmp rcx, 1
    je read_elf_u8
    cmp rcx, 2
    je read_elf_u16
    cmp rcx, 4
    je read_elf_u32
    cmp rcx, 8
    je read_elf_u64
    stc
    ret

unpack_token:
    cmp r15, r14
    jae .bad
    movzx rdx, byte [r15]
    inc r15
    test rdx, rdx
    jz .bad
    cmp rdx, 27
    jb .opcode_ok
    cmp rdx, 42
    jbe .bad
.opcode_ok:
    cmp rdx, OP_BLOB64
    ja .bad
    push rcx
    push rdx
    call unpack_uint
    pop rdx
    pop rcx
    jc .bad
    mov [r11], rdx
    mov [r11 + 8], rax
    add r11, 16
    clc
    ret
.bad:
    stc
    ret

unpack_uint:
    xor rax, rax
    xor ecx, ecx
.byte:
    cmp r15, r14
    jae .bad
    movzx rdx, byte [r15]
    inc r15
    mov r8, rdx
    and r8, 0x7f
    cmp ecx, 63
    jb .merge
    cmp ecx, 63
    jne .bad
    cmp r8, 1
    ja .bad
.merge:
    shl r8, cl
    or rax, r8
    test dl, 0x80
    jz .ok
    add ecx, 7
    cmp ecx, 70
    jb .byte
.bad:
    stc
    ret
.ok:
    clc
    ret

%ifndef PACKED_LOADER
define_layout_start:
    call pop_compile_literal
    jc .bad
    cmp rax, DATA_CELLS
    ja .bad
    cmp rax, [rbx + LAYOUT_HIGH_OFF]
    jb .bad
    mov [rbx + LAYOUT_CURSOR_OFF], rax
    mov [rbx + LAYOUT_HIGH_OFF], rax
    clc
    ret
.bad:
    stc
    ret

define_layout_union:
    call pop_compile_literal
    jc .bad
    cmp rax, DATA_CELLS
    ja .bad
    mov [rbx + LAYOUT_CURSOR_OFF], rax
    clc
    ret
.bad:
    stc
    ret

define_layout_cell:
    mov r8, [rbx + LAYOUT_CURSOR_OFF]
    cmp r8, DATA_CELLS
    jae .bad
    inc qword [rbx + LAYOUT_CURSOR_OFF]
    mov rax, [rbx + LAYOUT_CURSOR_OFF]
    cmp rax, [rbx + LAYOUT_HIGH_OFF]
    jbe .named
    mov [rbx + LAYOUT_HIGH_OFF], rax
.named:
    jmp define_layout_name
.bad:
    stc
    ret

define_layout_array:
    call pop_compile_literal
    jc .bad
    mov r8, [rbx + LAYOUT_CURSOR_OFF]
    add rax, r8
    jc .bad
    cmp rax, DATA_CELLS
    ja .bad
    mov [rbx + LAYOUT_CURSOR_OFF], rax
    cmp rax, [rbx + LAYOUT_HIGH_OFF]
    jbe .named
    mov [rbx + LAYOUT_HIGH_OFF], rax
.named:
    jmp define_layout_name
.bad:
    stc
    ret

define_layout_fields:
    call pop_compile_literal
    jc .bad
    cmp rax, 256
    ja .bad
    mov [rbx + FIELD_CURSOR_OFF], rax
    clc
    ret
.bad:
    stc
    ret

define_layout_field:
    mov r8, [rbx + FIELD_CURSOR_OFF]
    cmp r8, 256
    jae .bad
    inc qword [rbx + FIELD_CURSOR_OFF]
    jmp define_layout_name
.bad:
    stc
    ret

define_layout_width:
    mov r8, [rbx + FIELD_CURSOR_OFF]
    jmp define_layout_name

define_layout_records:
    call pop_compile_literal
    jc .bad
    mul qword [rbx + FIELD_CURSOR_OFF]
    test rdx, rdx
    jnz .bad
    mov r8, [rbx + LAYOUT_CURSOR_OFF]
    add rax, r8
    jc .bad
    cmp rax, DATA_CELLS
    ja .bad
    mov [rbx + LAYOUT_CURSOR_OFF], rax
    cmp rax, [rbx + LAYOUT_HIGH_OFF]
    jbe .named
    mov [rbx + LAYOUT_HIGH_OFF], rax
.named:
    jmp define_layout_name
.bad:
    stc
    ret

pop_compile_literal:
    cmp qword [rbx + WS_ORIG], 0
    je .bad
    cmp qword [r11 - 16], OP_LIT
    jne .bad
    mov rax, [r11 - 8]
    sub r11, 16
    dec qword [rbx + WS_ORIG]
    clc
    ret
.bad:
    stc
    ret

define_layout_name:
    call skip_ws
    cmp r15, r14
    jae .bad
    call scan_token
    test rsi, rsi
    jz .bad
    cmp rsi, 16
    ja .bad
    mov rcx, [rbx + WS_PREV_BASE]
    lea rax, [rcx + DICT_ENTRY_SIZE]
    lea rdx, [rbx + ORIG_BASE_OFF]
    cmp rax, rdx
    jae .bad
    mov [rbx + WS_PREV_BASE], rax
    inc qword [rbx + WS_PREV_COUNT]
    mov qword [rcx], DICT_CONST
    mov [rcx + 8], r8
    mov qword [rcx + 16], 0
    mov [rcx + 24], rsi
    mov qword [rcx + 32], 0
    mov qword [rcx + 40], 0
    xor r8, r8
.copy:
    cmp r8, rsi
    jae .ok
    mov al, [rdi + r8]
    mov [rcx + 32 + r8], al
    inc r8
    jmp .copy
.ok:
    clc
    ret
.bad:
    stc
    ret

define_constant:
    ; Forth syntax: <literal> constant <name>. Constants are compile-time only.
    cmp qword [rbx + WS_ORIG], 0
    je .bad
    cmp qword [r11 - 16], OP_LIT
    jne .bad
    mov r8, [r11 - 8]

    call skip_ws
    cmp r15, r14
    jae .bad
    call scan_token
    test rsi, rsi
    jz .bad
    cmp rsi, 16
    ja .bad

    sub r11, 16
    dec qword [rbx + WS_ORIG]

    mov rcx, [rbx + WS_PREV_BASE]
    lea rax, [rcx + DICT_ENTRY_SIZE]
    lea rdx, [rbx + PATH_BUFFER_BASE_OFF]
    cmp rax, rdx
    ja .bad
    mov [rbx + WS_PREV_BASE], rax
    inc qword [rbx + WS_PREV_COUNT]

    mov qword [rcx], DICT_CONST
    mov [rcx + 8], r8
    xor rax, rax
    mov [rcx + 16], rax
    mov [rcx + 24], rsi
    mov [rcx + 32], rax
    mov [rcx + 40], rax
    xor r8, r8
.copy:
    cmp r8, rsi
    jae .ok
    mov al, [rdi + r8]
    mov [rcx + 32 + r8], al
    inc r8
    jmp .copy
.ok:
    clc
    ret
.bad:
    stc
    ret

find_constant:
    ; rdi=token ptr, rsi=len. CF clear with rax=value if found.
    test rsi, rsi
    jz .bad
    cmp rsi, 16
    ja .bad
    mov rcx, [rbx + WS_PREV_COUNT]
    lea r8, [rbx + IMAGE_BASE_OFF + 49152]
.entry_loop:
    test rcx, rcx
    jz .bad
    cmp qword [r8], DICT_CONST
    jne .next
    cmp [r8 + 24], rsi
    jne .next
    xor r9, r9
.name_loop:
    cmp r9, rsi
    jae .found
    mov al, [rdi + r9]
    cmp al, [r8 + 32 + r9]
    jne .next
    inc r9
    jmp .name_loop
.found:
    mov rax, [r8 + 8]
    clc
    ret
.next:
    call dict_next_entry
    dec rcx
    jmp .entry_loop
.bad:
    stc
    ret

define_callable_word:
    ; Compile one reusable body and reference it through CALL tokens.
    push r12
    push r13
    push r10
    push r11

    call skip_ws
    cmp r15, r14
    jae .bad_restore
    call scan_token
    test rsi, rsi
    jz .bad_restore
    cmp rsi, 16
    ja .bad_restore
    mov r12, rdi
    mov r13, rsi

    mov rax, [rbx + WS_PREV_BASE]
    lea r11, [rax + DICT_ENTRY_SIZE]
    lea r10, [rbx + ORIG_BASE_OFF]
    cmp r11, r10
    jae .bad_restore

.body_loop:
    call skip_ws
    cmp r15, r14
    jae .bad_restore
    mov rdi, r15
    call scan_token
    cmp rsi, 1
    jne .compile_body_token
    cmp byte [rdi], ';'
    je .finish
.compile_body_token:
    call try_word
    jnc .body_loop
    call parse_number
    jc .bad_restore
    call compile_number
    jmp .body_loop

.finish:
    mov rax, OP_RET
    xor rdx, rdx
    call emit_orig_token
    jc .bad_restore
    mov r8, [rbx + WS_PREV_BASE]
    lea r9, [r8 + DICT_ENTRY_SIZE]
    mov rax, r11
    sub rax, r9
    shr rax, 4
    push rax
    push r9
    mov rcx, rax
    mov rsi, r9
    mov rdi, 32
.effect_loop:
    test rcx, rcx
    jz .effect_done
    mov rax, [rsi]
    mov rdx, [rsi + 8]
    cmp rax, OP_BR
    jne .effect_token
    test rdx, rdx
    jle .bad_restore
    cmp rdx, rcx
    jae .bad_restore
    sub rcx, rdx
    shl rdx, 4
    add rsi, rdx
    xor rdx, rdx
.effect_token:
    push rcx
    push rsi
    call update_transform_depth
    pop rsi
    pop rcx
    add rsi, 16
    dec rcx
    jmp .effect_loop
.effect_done:
    sub rdi, 32
    pop r9
    pop rax
    mov r10, rax
    push rax
    push r9
    mov rcx, rax
    mov rsi, r9
    call transform_callable_body
    pop r9
    pop rax
    mov r11, rax
    shl r11, 4
    add r11, r9
    sub r11, 16
    mov rcx, MAX_ROUNDS
    mov rdx, rcx
    inc rdx
    shl rdx, 4
    add rdx, r11
    lea rsi, [rbx + ORIG_BASE_OFF]
    cmp rdx, rsi
    jae .body_noop_done
.body_noop_loop:
    test rcx, rcx
    jz .body_noop_done
    mov rdx, [r11]
    mov rsi, [r11 + 8]
    mov [r11 + 16], rdx
    mov [r11 + 24], rsi
    mov qword [r11], OP_NOP_ALT
    mov qword [r11 + 8], 0
    add r11, 16
    inc rax
    inc qword [rbx + WS_XFORMS]
    dec rcx
    jmp .body_noop_loop
.body_noop_done:
    add r11, 16
    lea rdx, [rbx + ORIG_BASE_OFF]
    cmp r11, rdx
    jae .bad_restore
    sub [rbx + WS_ORIG], r10
    add dword [rbx + WS_WORD_META], r10d
    inc word [rbx + WS_WORD_META + 4]
    mov qword [r8], DICT_CALLABLE
    mov [r8 + 8], rax
    mov [r8 + 10], di
    mov [r8 + 16], r9
    mov [r8 + 24], r13
    mov qword [r8 + 32], 0
    mov qword [r8 + 40], 0
    xor r9, r9
.copy_name:
    cmp r9, r13
    jae .ok_restore
    mov al, [r12 + r9]
    mov [r8 + 32 + r9], al
    inc r9
    jmp .copy_name
.ok_restore:
    mov [rbx + WS_PREV_BASE], r11
    inc qword [rbx + WS_PREV_COUNT]
    pop r11
    pop r10
    pop r13
    pop r12
    clc
    ret
.bad_restore:
    pop r11
    pop r10
    pop r13
    pop r12
    stc
    ret
%endif

transform_callable_body:
    ; Word bodies have stable slots. Each generation rewrites their token
    ; encodings once, so all call sites continue to share one polymorphic body.
    push r8
    push r9
    push r10
    push r11
    mov r8, [rbx + WS_ROUNDS]
.round:
    test r8, r8
    jz .done
    mov r9, rcx
    mov r10, rsi
.token:
    test r9, r9
    jz .next_round
    call next_rand
    test al, 1
    jz .advance
    mov r11, [r10]
    cmp r11, OP_LIT
    je .lit
    cmp r11, OP_LIT_INV
    je .lit_inv
    cmp r11, OP_ADD
    je .add
    cmp r11, OP_ADD_ALT
    je .add_base
    cmp r11, OP_SUB
    je .sub
    cmp r11, OP_SUB_ALT
    je .sub_base
    cmp r11, OP_EQ
    je .eq
    cmp r11, OP_EQ_ALT
    je .eq_base
    cmp r11, OP_LT
    je .lt
    cmp r11, OP_LT_ALT
    je .lt_base
    cmp r11, OP_GT
    je .gt
    cmp r11, OP_GT_ALT
    je .gt_base
    cmp r11, OP_THEN
    je .nop
    cmp r11, OP_NOP_ALT
    je .then
    jmp .advance
.lit:
    mov qword [r10], OP_LIT_INV
    not qword [r10 + 8]
    jmp .changed
.lit_inv:
    mov qword [r10], OP_LIT
    not qword [r10 + 8]
    jmp .changed
.add:
    mov qword [r10], OP_ADD_ALT
    jmp .changed
.add_base:
    mov qword [r10], OP_ADD
    jmp .changed
.sub:
    mov qword [r10], OP_SUB_ALT
    jmp .changed
.sub_base:
    mov qword [r10], OP_SUB
    jmp .changed
.eq:
    mov qword [r10], OP_EQ_ALT
    jmp .changed
.eq_base:
    mov qword [r10], OP_EQ
    jmp .changed
.lt:
    mov qword [r10], OP_LT_ALT
    jmp .changed
.lt_base:
    mov qword [r10], OP_LT
    jmp .changed
.gt:
    mov qword [r10], OP_GT_ALT
    jmp .changed
.gt_base:
    mov qword [r10], OP_GT
    jmp .changed
.nop:
    mov qword [r10], OP_NOP_ALT
    jmp .changed
.then:
    mov qword [r10], OP_THEN
.changed:
    inc qword [rbx + WS_XFORMS]
.advance:
    add r10, 16
    dec r9
    jmp .token
.next_round:
    dec r8
    jmp .round
.done:
    pop r11
    pop r10
    pop r9
    pop r8
    ret

%ifndef PACKED_LOADER
expand_inline_word:
    ; Resolve one reusable callable word.
    test rsi, rsi
    jz .bad
    cmp rsi, 16
    ja .bad
    mov rcx, [rbx + WS_PREV_COUNT]
    lea r8, [rbx + IMAGE_BASE_OFF + 49152]
.entry_loop:
    test rcx, rcx
    jz .bad
    cmp qword [r8], DICT_CALLABLE
    jne .next
    cmp [r8 + 24], rsi
    jne .next
    xor r9, r9
.name_loop:
    cmp r9, rsi
    jae .found
    mov al, [rdi + r9]
    cmp al, [r8 + 32 + r9]
    jne .next
    inc r9
    jmp .name_loop
.found:
    movzx rdx, word [r8 + 8]
    shl rdx, 32
    movzx rcx, word [r8 + 10]
    shl rcx, 48
    or rdx, rcx
    mov rax, [r8 + 16]
    sub rax, rbx
    or rdx, rax
    mov rax, OP_CALL
    call emit_orig_token
    ret
.next:
    call dict_next_entry
    dec rcx
    jmp .entry_loop
.bad:
    stc
    ret

dict_next_entry:
    cmp qword [r8], DICT_CALLABLE
    jne .plain
.body:
    movzx rax, word [r8 + 8]
    shl rax, 4
    lea r8, [r8 + DICT_ENTRY_SIZE + rax]
    ret
.plain:
    add r8, DICT_ENTRY_SIZE
    ret
%endif

ensure_push:
    lea rax, [rbx + WS_HDR_SIZE + STACK_SIZE - LOOP_STATE_SIZE]
    lea rdx, [rbp + 8]
    cmp rdx, rax
    ja .bad
    clc
    ret
.bad:
    stc
    ret

record_depth:
    mov rax, rbp
    lea rdx, [rbx + WS_HDR_SIZE]
    sub rax, rdx
    shr rax, 3
    cmp rax, [rbx + WS_MAX_DEPTH]
    jbe .done
    mov [rbx + WS_MAX_DEPTH], rax
.done:
    ret

record_trace:
    ; rax=event, rdx=op, r8=imm/detail, r9=aux/count. Preserves token pointers.
    push rcx
    push rdi
    mov rcx, [rbx + WS_TRACE_COUNT]
    cmp rcx, TRACE_LIMIT
    jae .done
    mov rdi, [rbx + WS_TRACE_BASE]
    shl rcx, 5
    add rdi, rcx
    mov [rdi], rax
    mov [rdi + 8], rdx
    mov [rdi + 16], r8
    mov [rdi + 24], r9
    inc qword [rbx + WS_TRACE_COUNT]
.done:
    pop rdi
    pop rcx
    ret

update_transform_depth:
    cmp rax, OP_CALL
    je .call_effect
    cmp rax, OP_RET
    je .done
    cmp rax, OP_LIT
    je .push1
    cmp rax, OP_DUP
    je .push1
    cmp rax, OP_OVER
    je .push1
    cmp rax, OP_DROP
    je .pop1
    cmp rax, OP_DOT
    je .pop1
    cmp rax, OP_EMIT
    je .pop1
    cmp rax, OP_ADD
    je .binary
    cmp rax, OP_SUB
    je .binary
    cmp rax, OP_MUL
    je .binary
    cmp rax, OP_EQ
    je .binary
    cmp rax, OP_LT
    je .binary
    cmp rax, OP_GT
    je .binary
    cmp rax, OP_AND
    je .binary
    cmp rax, OP_OR
    je .binary
    cmp rax, OP_XOR
    je .binary
    cmp rax, OP_LSHIFT
    je .binary
    cmp rax, OP_RSHIFT
    je .binary
    cmp rax, OP_ULT
    je .binary
    cmp rax, OP_UGT
    je .binary
    cmp rax, OP_MIN
    je .binary
    cmp rax, OP_MAX
    je .binary
    cmp rax, OP_UDIV
    je .binary
    cmp rax, OP_FOR
    je .pop1
    cmp rax, OP_I
    je .push1
    cmp rax, OP_NEXT
    je .done
    cmp rax, OP_BRZ
    je .pop1
    cmp rax, OP_BR
    je .done
    cmp rax, OP_THEN
    je .done
    cmp rax, OP_MFETCH
    je .need1_same
    cmp rax, OP_BLOB64
    je .need1_same
    cmp rax, OP_MSTORE
    je .pop2
    cmp rax, OP_I8FETCH
    je .need1_same
    cmp rax, OP_I64FETCH
    je .need1_same
    cmp rax, OP_I8STORE
    je .pop2
    cmp rax, OP_I64STORE
    je .pop2
    cmp rax, OP_ECOPY
    je .pop4
    cmp rax, OP_O64STORE
    je .pop3
    cmp rax, OP_OSMAP
    je .mapcall
    cmp rax, OP_O64FETCH
    je .binary
    cmp rax, OP_O8FETCH
    je .binary
    cmp rax, OP_OSUNMAP
    je .binary
    cmp rax, OP_OSPROTECT
    je .ternary
    cmp rax, OP_OSREAD
    je .mapcall
    cmp rax, OP_OSCLOSE
    je .need1_same
    cmp rax, OP_PBASE
    je .push1
    cmp rax, OP_P8FETCH
    je .need1_same
    cmp rax, OP_P8STORE
    je .pop2
    cmp rax, OP_ESOURCE
    je .pop1
    cmp rax, OP_OCALL
    je .binary
    cmp rax, OP_STREQ
    je .mapcall
    cmp rax, OP_OSCOPY
    je .ternary
    cmp rax, OP_CPUID
    je .cpuid_effect
    cmp rax, OP_SYSCALL6
    je .syscall_effect
    cmp rax, OP_NEG
    je .done
    cmp rax, OP_ZEROEQ
    je .done
    cmp rax, OP_ONEPLUS
    je .done
    cmp rax, OP_ONEMINUS
    je .done
    cmp rax, OP_INVERT
    je .done
    cmp rax, OP_2MUL
    je .done
    cmp rax, OP_EBASE
    je .push1
    cmp rax, OP_ELEN
    je .push1
    cmp rax, OP_U8
    je .need1_same
    cmp rax, OP_U16
    je .need1_same
    cmp rax, OP_U32
    je .need1_same
    cmp rax, OP_U64
    je .need1_same
    cmp rax, OP_AND
    je .binary
    cmp rax, OP_OR
    je .binary
    cmp rax, OP_XOR
    je .binary
    cmp rax, OP_LSHIFT
    je .binary
    cmp rax, OP_RSHIFT
    je .binary
    cmp rax, OP_ULT
    je .binary
    cmp rax, OP_UGT
    je .binary
    cmp rax, OP_MIN
    je .binary
    cmp rax, OP_MAX
    je .binary
    ret
.push1:
    inc rdi
    ret
.pop1:
    test rdi, rdi
    jz .done
    dec rdi
.done:
    ret
.binary:
    cmp rdi, 2
    jb .done
    dec rdi
    ret
.pop2:
    cmp rdi, 2
    jb .done
    sub rdi, 2
    ret
.pop3:
    cmp rdi, 3
    jb .done
    sub rdi, 3
    ret
.pop4:
    cmp rdi, 4
    jb .done
    sub rdi, 4
    ret
.mapcall:
    cmp rdi, 4
    jb .done
    sub rdi, 3
    ret
.ternary:
    cmp rdi, 3
    jb .done
    sub rdi, 2
    ret
.cpuid_effect:
    cmp rdi, 2
    jb .done
    add rdi, 2
    ret
.syscall_effect:
    cmp rdi, 7
    jb .done
    sub rdi, 6
    ret
.need1_same:
    test rdi, rdi
    jz .done
    ret
.call_effect:
    mov rcx, rdx
    sar rcx, 48
    add rdi, rcx
    jns .done
    xor rdi, rdi
    ret

maybe_post_neutral:
    ; Add neutral work after result-producing ops when the simulated stack is non-empty.
    cmp rax, OP_OSMAP
    je .done
    cmp rax, OP_O64FETCH
    je .done
    cmp rax, OP_O8FETCH
    je .done
    cmp rdi, 1
    jb .done
    call next_rand
    and rax, 7
    cmp rax, 0
    je .emit_add_zero
    cmp rax, 1
    je .emit_mul_one
    cmp rax, 2
    je .emit_invert_pair
    cmp rax, 3
    je .emit_inc_dec_pair
    jmp .done
.emit_add_zero:
    mov rax, OP_LIT
    xor rdx, rdx
    call emit_xform_token
    jc .done
    mov rax, OP_ADD
    xor rdx, rdx
    call emit_xform_token
    jc .done
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_POST_NEUTRAL
    mov rdx, OP_ADD
    mov r8, rdi
    mov r9, 2
    call record_trace
    jmp .done
.emit_mul_one:
    mov rax, OP_LIT
    mov rdx, 1
    call emit_xform_token
    jc .done
    mov rax, OP_MUL
    xor rdx, rdx
    call emit_xform_token
    jc .done
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_POST_NEUTRAL
    mov rdx, OP_MUL
    mov r8, rdi
    mov r9, 2
    call record_trace
.done_after_mul:
    jmp .done
.emit_invert_pair:
    mov rax, OP_INVERT
    xor rdx, rdx
    call emit_xform_token
    jc .done
    mov rax, OP_INVERT
    xor rdx, rdx
    call emit_xform_token
    jc .done
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_INVERT_PAIR
    mov rdx, OP_INVERT
    mov r8, rdi
    mov r9, 2
    call record_trace
    jmp .done
.emit_inc_dec_pair:
    mov rax, OP_ONEPLUS
    xor rdx, rdx
    call emit_xform_token
    jc .done
    mov rax, OP_ONEMINUS
    xor rdx, rdx
    call emit_xform_token
    jc .done
    inc qword [rbx + WS_XFORMS]
    mov rax, TR_POST_NEUTRAL
    mov rdx, OP_ONEPLUS
    mov r8, rdi
    mov r9, 2
    call record_trace
.done:
    ret

repair_branch_offsets:
    ; Recompute relative token offsets after variable-length transforms have
    ; inserted or rewritten tokens.
    mov r15, [rbx + WS_XFORM_BASE]
    mov rax, [rbx + WS_XTOK]
    shl rax, 4
    lea r14, [r15 + rax]
    mov r8, -1          ; active for token index, or -1 when outside a loop
    xor r9, r9          ; branch control depth
    xor rdi, rdi        ; transformed token index
.loop:
    cmp r15, r14
    jae .done
    mov rax, [r15]
    cmp rax, OP_FOR
    je .seen_for
    cmp rax, OP_NEXT
    je .seen_next
    cmp rax, OP_BRZ
    je .seen_brz
    cmp rax, OP_BR
    je .seen_br
    cmp rax, OP_THEN
    je .seen_then
.advance:
    add r15, 16
    inc rdi
    jmp .loop
.seen_for:
    cmp r8, -1
    jne .bad
    mov r8, rdi
    jmp .advance
.seen_next:
    cmp r8, -1
    je .bad
    mov rax, rdi
    sub rax, r8
    mov r10, [rbx + WS_XFORM_BASE]
    mov rdx, r8
    shl rdx, 4
    mov [r10 + rdx + 8], rax
    neg rax
    mov [r15 + 8], rax
    mov r8, -1
    jmp .advance
.seen_brz:
    cmp r9, CTRL_LIMIT
    jae .bad
    lea r11, [rbx + CTRL_BASE_OFF]
    mov rax, r9
    shl rax, 5
    mov [r11 + rax], rdi
    mov qword [r11 + rax + 8], CTRL_IF
    inc r9
    jmp .advance
.seen_br:
    test r9, r9
    jz .bad
    lea r11, [rbx + CTRL_BASE_OFF]
    mov rax, r9
    dec rax
    shl rax, 5
    cmp qword [r11 + rax + 8], CTRL_IF
    jne .bad
    mov rdx, [r11 + rax]
    mov rcx, rdi
    sub rcx, rdx
    mov r10, [rbx + WS_XFORM_BASE]
    shl rdx, 4
    mov [r10 + rdx + 8], rcx
    shr rdx, 4
    mov [r11 + rax], rdi
    mov qword [r11 + rax + 8], CTRL_ELSE
    jmp .advance
.seen_then:
    test r9, r9
    jz .bad
    dec r9
    lea r11, [rbx + CTRL_BASE_OFF]
    mov rax, r9
    shl rax, 5
    mov rcx, [r11 + rax + 8]
    cmp rcx, CTRL_IF
    je .patch_then
    cmp rcx, CTRL_ELSE
    jne .bad
.patch_then:
    mov rdx, [r11 + rax]
    mov rcx, rdi
    sub rcx, rdx
    mov r10, [rbx + WS_XFORM_BASE]
    shl rdx, 4
    mov [r10 + rdx + 8], rcx
    jmp .advance
.done:
    cmp r8, -1
    jne .bad
    test r9, r9
    jnz .bad
    clc
    ret
.bad:
    mov qword [rbx + WS_VALIDATE], -1
    mov [rbx + WS_ERROR_AT], rdi
    stc
    ret

validate_xform:
    ; Validate transformed token stream stack effects before execution.
    ; CF clear = valid. CF set = invalid; execution will fall back to original IR.
    push r11
    mov r15, [rbx + WS_XFORM_BASE]
    mov r11, [rbx + WS_XTOK]
    mov rax, r11
    shl rax, 4
    lea r14, [r15 + rax]
    xor r8, r8          ; simulated depth
    xor r9, r9          ; simulated max depth
    xor rdi, rdi        ; token index
.loop:
    cmp r15, r14
    jae .ok
    mov rax, [r15]
    mov rdx, [r15 + 8]
    add r15, 16

    cmp rax, OP_LIT
    je .push1
    cmp rax, OP_DUP
    je .dup
    cmp rax, OP_DROP
    je .pop1
    cmp rax, OP_SWAP
    je .need2_same
    cmp rax, OP_OVER
    je .over
    cmp rax, OP_ADD
    je .binary
    cmp rax, OP_SUB
    je .binary
    cmp rax, OP_MUL
    je .binary
    cmp rax, OP_EQ
    je .binary
    cmp rax, OP_LT
    je .binary
    cmp rax, OP_GT
    je .binary
    cmp rax, OP_AND
    je .binary
    cmp rax, OP_OR
    je .binary
    cmp rax, OP_XOR
    je .binary
    cmp rax, OP_LSHIFT
    je .binary
    cmp rax, OP_RSHIFT
    je .binary
    cmp rax, OP_ULT
    je .binary
    cmp rax, OP_UGT
    je .binary
    cmp rax, OP_MIN
    je .binary
    cmp rax, OP_MAX
    je .binary
    cmp rax, OP_UDIV
    je .binary
    cmp rax, OP_DOT
    je .pop1
    cmp rax, OP_EMIT
    je .pop1
    cmp rax, OP_CR
    je .next
    cmp rax, OP_NEG
    je .need1_same
    cmp rax, OP_ZEROEQ
    je .need1_same
    cmp rax, OP_ONEPLUS
    je .need1_same
    cmp rax, OP_ONEMINUS
    je .need1_same
    cmp rax, OP_INVERT
    je .need1_same
    cmp rax, OP_2MUL
    je .need1_same
    cmp rax, OP_EBASE
    je .push1
    cmp rax, OP_ELEN
    je .push1
    cmp rax, OP_U8
    je .need1_same
    cmp rax, OP_U16
    je .need1_same
    cmp rax, OP_U32
    je .need1_same
    cmp rax, OP_U64
    je .need1_same
    cmp rax, OP_FOR
    je .for
    cmp rax, OP_I
    je .push1
    cmp rax, OP_NEXT
    je .next_branch
    cmp rax, OP_BRZ
    je .branch_zero
    cmp rax, OP_BR
    je .branch_always
    cmp rax, OP_THEN
    je .next
    cmp rax, OP_MFETCH
    je .need1_same
    cmp rax, OP_MSTORE
    je .pop2
    cmp rax, OP_I8FETCH
    je .need1_same
    cmp rax, OP_I64FETCH
    je .need1_same
    cmp rax, OP_I8STORE
    je .pop2
    cmp rax, OP_I64STORE
    je .pop2
    cmp rax, OP_ECOPY
    je .pop4
    cmp rax, OP_O64STORE
    je .pop3
    cmp rax, OP_OSMAP
    je .mapcall
    cmp rax, OP_O64FETCH
    je .binary
    cmp rax, OP_O8FETCH
    je .binary
    cmp rax, OP_OSUNMAP
    je .binary
    cmp rax, OP_OSPROTECT
    je .ternary
    cmp rax, OP_OSREAD
    je .mapcall
    cmp rax, OP_OSCLOSE
    je .need1_same
    cmp rax, OP_PBASE
    je .push1
    cmp rax, OP_P8FETCH
    je .need1_same
    cmp rax, OP_P8STORE
    je .pop2
    cmp rax, OP_ESOURCE
    je .pop1
    cmp rax, OP_OCALL
    je .binary
    cmp rax, OP_STREQ
    je .mapcall
    cmp rax, OP_OSCOPY
    je .ternary
    cmp rax, OP_CPUID
    je .cpuid_effect
    cmp rax, OP_SYSCALL6
    je .syscall_effect
    cmp rax, OP_CALL
    je .call_effect
    cmp rax, OP_RET
    je .bad
    jmp .bad

.push1:
    inc r8
    cmp r8, STACK_CELLS
    ja .bad
    cmp r8, r9
    jbe .next
    mov r9, r8
    jmp .next

.call_effect:
    mov rcx, rdx
    sar rcx, 48
    add r8, rcx
    js .bad
    cmp r8, STACK_CELLS
    ja .bad
    cmp r8, r9
    jbe .next
    mov r9, r8
    jmp .next

.dup:
    cmp r8, 1
    jb .bad
    jmp .push1

.over:
    cmp r8, 2
    jb .bad
    jmp .push1

.pop1:
    cmp r8, 1
    jb .bad
    dec r8
    jmp .next

.pop2:
    cmp r8, 2
    jb .bad
    sub r8, 2
    jmp .next

.pop3:
    cmp r8, 3
    jb .bad
    sub r8, 3
    jmp .next

.pop4:
    cmp r8, 4
    jb .bad
    sub r8, 4
    jmp .next
.mapcall:
    cmp r8, 4
    jb .bad
    sub r8, 3
    jmp .next
.ternary:
    cmp r8, 3
    jb .bad
    sub r8, 2
    jmp .next
.cpuid_effect:
    cmp r8, 2
    jb .bad
    add r8, 2
    cmp r8, STACK_CELLS
    ja .bad
    cmp r8, r9
    jbe .next
    mov r9, r8
    jmp .next
.syscall_effect:
    cmp r8, 7
    jb .bad
    sub r8, 6
    jmp .next

.binary:
    cmp r8, 2
    jb .bad
    dec r8
    jmp .next

.need2_same:
    cmp r8, 2
    jb .bad
    jmp .next

.need1_same:
    cmp r8, 1
    jb .bad
    jmp .next

.for:
    cmp r8, 1
    jb .bad
    test rdx, rdx
    jle .bad
    mov rax, rdi
    add rax, rdx
    jc .bad
    cmp rax, r11
    jae .bad
    dec r8
    jmp .next

.next_branch:
    test rdx, rdx
    jns .bad
    mov rax, rdi
    add rax, rdx
    cmp rax, rdi
    jae .bad
    jmp .next

.branch_zero:
    cmp r8, 1
    jb .bad
    test rdx, rdx
    jle .bad
    mov rax, rdi
    add rax, rdx
    jc .bad
    cmp rax, r11
    jae .bad
    dec r8
    jmp .next

.branch_always:
    test rdx, rdx
    jle .bad
    mov rax, rdi
    add rax, rdx
    jc .bad
    cmp rax, r11
    jae .bad
    inc rax
    mov rdi, rax
    shl rax, 4
    mov r15, [rbx + WS_XFORM_BASE]
    add r15, rax
    jmp .loop

.next:
    inc rdi
    jmp .loop

.ok:
    mov qword [rbx + WS_VALIDATE], 1
    mov [rbx + WS_MAX_DEPTH], r9
    pop r11
    clc
    ret

.bad:
    mov qword [rbx + WS_VALIDATE], -1
    mov [rbx + WS_ERROR_AT], rdi
    pop r11
    stc
    ret

append_char:
    cmp r13, r12
    jae .bad
    mov [r13], al
    inc r13
    clc
    ret
.bad:
    stc
    ret

append_int:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    sub rsp, 32
    xor r10, r10
    test rax, rax
    jns .positive
    neg rax
    mov r11, rax
    mov al, '-'
    call append_char
    jc .fail
    mov rax, r11
.positive:
    lea r8, [rsp + 31]
    mov r9, 10
    cmp rax, 0
    jne .digits
    mov byte [r8], '0'
    mov r10, 1
    jmp .write
.digits:
    xor rdx, rdx
    div r9
    add dl, '0'
    mov [r8], dl
    dec r8
    inc r10
    test rax, rax
    jne .digits
    inc r8
.write:
    test r10, r10
    jz .ok
    mov al, [r8]
    call append_char
    jc .fail
    inc r8
    dec r10
    jmp .write
.ok:
    add rsp, 32
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    clc
    ret
.fail:
    add rsp, 32
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    stc
    ret

align 16
loader_source:
%ifdef PACKED_LOADER
incbin "build/elf64_dryload.fthp"
%else
incbin "examples/elf64_dryload.fs"
%endif
loader_source_end:
standalone_failure_text:
db "forth-loader: rejected", 10
standalone_failure_text_end:
align 8
adapter_data:
dq 13110149179372173069, 2211186601827319471, 2524768844, 228112, 41, 229376, 2145624
dq 16444297556784476094, 11222618495177343952, 344351455, 0, 22, 2236416, 3974248
dq 3839366009233861826, 13122167812550496623, 1723684218, 0, 30, 2293792, 4011968
dq 10854769716642063645, 17088051658300671335, 1682898131, 232304, 38, 233472, 2110368
dq 7101667281903827675, 3184216553623061584, 2723096564, 0, 32, 188512, 2029056
dq 6073846211301200870, 8400369109440244580, 4161799383, 236368, 37, 237632, 2236928
dq 11870973152507313278, 4067365816616924312, 2846587447, 207664, 39, 208928, 1946400
dq 228000, 2113200, 2235392, 3960392, 2292608, 3997272, 232192
dq 2076336, 185888, 2014816, 236256, 2203336, 207552, 1912472

%ifdef EMBEDDED_BUNDLE
align 8
embedded_argv0:
db "embedded-static"
embedded_argv0_end:
align 8
embedded_manifest:
dq BUNDLE_MAGIC, 1, 0, 0, 0, 1, 1, 0, 0, 0
embedded_template_end:
%endif
