ASM := nasm
CC := cc
LD := ld
PY := python3

BUILD := build
BUILD_STAMP := $(BUILD)/.dir
SHELL_OBJ := $(BUILD)/forth_vm.o
SHELL_BIN := $(BUILD)/forth.bin
DEV_OBJ := $(BUILD)/forth_vm_dev.o
DEV_BIN := $(BUILD)/forth_dev.bin
COMPILED_RAW := $(BUILD)/elf64_dryload.fthc
COMPILED_PACKED := $(BUILD)/elf64_dryload.fthp
COMPILED_INSTRUMENTED := $(BUILD)/elf64_dryload.instrumented.fthp
STANDALONE_OBJ := $(BUILD)/standalone_loader.o
STANDALONE_BIN := $(BUILD)/standalone_loader.bin
EMBEDDED_OBJ := $(BUILD)/standalone_loader.template.o
EMBEDDED_BIN := $(BUILD)/standalone_loader.template.bin
EMBEDDED_STATIC := $(BUILD)/hello_static.bundle
EMBEDDED_STATIC_PIE := $(BUILD)/hello_static_pie.bundle
GO_STATIC := $(BUILD)/go_static
EMBEDDED_GO_STATIC := $(BUILD)/go_static.bundle
SIGNAL_STATIC_PIE := $(BUILD)/hello_static_pie.signal.bundle
SIGNAL_GO_STATIC := $(BUILD)/go_static.signal.bundle
HARNESS := $(BUILD)/c_harness
STANDALONE_LAUNCHER := $(BUILD)/standalone_launcher
FIXED_STANDALONE_LAUNCHER := $(BUILD)/standalone_launcher_fixed
AUDIT_STANDALONE_LAUNCHER := $(BUILD)/standalone_launcher_audit
HELLO_DYNAMIC := $(BUILD)/hello_dynamic
HELLO_STATIC_OBJ := $(BUILD)/hello_static.o
HELLO_STATIC := $(BUILD)/hello_static
HELLO_STATIC_PIE := $(BUILD)/hello_static_pie
HELLO_WX := $(BUILD)/hello_wx
HELLO_DEPENDENCY := $(BUILD)/libhello_dependency.so
HELLO_WITH_DEPENDENCY := $(BUILD)/hello_with_dependency
WRONG_DEPENDENCY := $(BUILD)/libwrong_dependency.so
WRONG_PLACEHOLDER := $(BUILD)/libwrong_placeholder.so
VERSIONED_DEPENDENCY := $(BUILD)/versioned_dependency
UNKNOWN_LD := $(BUILD)/unknown/ld-linux-x86-64.so.2
UNKNOWN_GLIBC := $(BUILD)/unknown_glibc
IFUNC_DEPENDENCY := $(BUILD)/libifunc_dependency.so
IFUNC_PROGRAM := $(BUILD)/ifunc_program
MUSL_DEPENDENCY := $(BUILD)/libhello_musl.so
MUSL_WITH_DEPENDENCY := $(BUILD)/hello_musl
MUSL_STATIC := $(BUILD)/hello_musl_static
MUSL_STATIC_PIE := $(BUILD)/hello_musl_static_pie
MUSL_STATIC_TLS := $(BUILD)/hello_musl_static_tls
MUSL_STATIC_PIE_TLS := $(BUILD)/hello_musl_static_pie_tls
HELLO_DYNAMIC_STRIPPED := $(BUILD)/hello_dynamic_stripped
BENIGN_CONTROL := $(BUILD)/benign_control
PROBE_EVENTS := $(BUILD)/probe_events.jsonl
PROBE_FINDINGS := $(BUILD)/probe_findings.jsonl
CONTROL_EVENTS := $(BUILD)/control_events.jsonl

CFLAGS := -std=c11 -Wall -Wextra -Werror -O2 -g -fpie -pie -Iinclude

.PHONY: all build check run-c run-py inspect test boundary-check packed-parity compact-test callable-test syscall-test standalone-test embedded-static-test ruby-perl-runner-test demo-test matrix-test standalone-audit probe-test probe-live probe-control clean

all: build

check: test standalone-test embedded-static-test ruby-perl-runner-test

build: $(STANDALONE_BIN) $(EMBEDDED_BIN)

$(COMPILED_RAW): $(HARNESS) $(DEV_BIN) examples/elf64_dryload.fs
	$(HARNESS) --blob $(DEV_BIN) --script examples/elf64_dryload.fs --rounds 0 --emit-compiled $@

$(COMPILED_PACKED): $(COMPILED_RAW) tools/pack_compiled.py
	$(PY) tools/pack_compiled.py --compact $< $@

$(COMPILED_INSTRUMENTED): $(COMPILED_RAW) tools/pack_compiled.py
	$(PY) tools/pack_compiled.py $< $@

$(STANDALONE_LAUNCHER): harness/standalone_launcher.c | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 $< -o $@

$(FIXED_STANDALONE_LAUNCHER): harness/standalone_launcher.c | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 -fno-pie -no-pie $< -o $@

$(AUDIT_STANDALONE_LAUNCHER): harness/standalone_launcher.c | $(BUILD_STAMP)
	musl-gcc -static -std=c11 -Wall -Wextra -Werror -O2 $< -o $@

build: $(SHELL_BIN) $(HARNESS) $(STANDALONE_LAUNCHER) $(HELLO_DYNAMIC) $(HELLO_DYNAMIC_STRIPPED) $(HELLO_STATIC) $(HELLO_STATIC_PIE) $(HELLO_WITH_DEPENDENCY) $(VERSIONED_DEPENDENCY) $(UNKNOWN_GLIBC) $(IFUNC_PROGRAM) $(MUSL_WITH_DEPENDENCY) $(MUSL_STATIC) $(MUSL_STATIC_PIE) $(MUSL_STATIC_TLS) $(MUSL_STATIC_PIE_TLS) $(BENIGN_CONTROL) $(EMBEDDED_GO_STATIC)

$(BUILD_STAMP):
	mkdir -p $(BUILD)
	touch $@

$(SHELL_OBJ): src/forth_vm.asm include/workspace.inc $(COMPILED_PACKED) | $(BUILD_STAMP)
	$(ASM) -DPACKED_LOADER -f elf64 $< -o $@

$(SHELL_BIN): $(SHELL_OBJ)
	objcopy -O binary -j .text $< $@

$(DEV_OBJ): src/forth_vm.asm include/workspace.inc examples/elf64_dryload.fs | $(BUILD_STAMP)
	$(ASM) -f elf64 $< -o $@

$(DEV_BIN): $(DEV_OBJ)
	objcopy -O binary -j .text $< $@

$(STANDALONE_OBJ): src/forth_vm.asm include/workspace.inc $(COMPILED_PACKED) | $(BUILD_STAMP)
	$(ASM) -DPACKED_LOADER -DSTANDALONE_ONLY -f elf64 $< -o $@

$(STANDALONE_BIN): $(STANDALONE_OBJ)
	objcopy -O binary -j .text $< $@

$(EMBEDDED_OBJ): src/forth_vm.asm include/workspace.inc $(COMPILED_PACKED) | $(BUILD_STAMP)
	$(ASM) -DPACKED_LOADER -DSTANDALONE_ONLY -DEMBEDDED_BUNDLE -f elf64 $< -o $@

$(EMBEDDED_BIN): $(EMBEDDED_OBJ)
	objcopy -O binary -j .text $< $@

$(EMBEDDED_STATIC): $(EMBEDDED_BIN) $(HELLO_STATIC) tools/pack_standalone.py
	$(PY) tools/pack_standalone.py $(EMBEDDED_BIN) $(HELLO_STATIC) $@

$(EMBEDDED_STATIC_PIE): $(EMBEDDED_BIN) $(HELLO_STATIC_PIE) tools/pack_standalone.py
	$(PY) tools/pack_standalone.py $(EMBEDDED_BIN) $(HELLO_STATIC_PIE) $@

$(GO_STATIC): examples/go_static.go | $(BUILD_STAMP)
	GOCACHE=$(abspath $(BUILD)/go-cache) CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -buildvcs=false -ldflags='-s -w -buildid= -T=0x2000000' -o $@ $<

$(EMBEDDED_GO_STATIC): $(EMBEDDED_BIN) $(GO_STATIC) tools/pack_standalone.py
	$(PY) tools/pack_standalone.py $(EMBEDDED_BIN) $(GO_STATIC) $@

$(SIGNAL_STATIC_PIE): $(EMBEDDED_BIN) $(HELLO_STATIC_PIE) tools/pack_standalone.py
	$(PY) tools/pack_standalone.py --signal-entry $(EMBEDDED_BIN) $(HELLO_STATIC_PIE) $@

$(SIGNAL_GO_STATIC): $(EMBEDDED_BIN) $(GO_STATIC) tools/pack_standalone.py
	$(PY) tools/pack_standalone.py --signal-entry $(EMBEDDED_BIN) $(GO_STATIC) $@

$(HARNESS): harness/c_harness.c include/workspace.h | $(BUILD_STAMP)
	$(CC) $(CFLAGS) $< -o $@

$(HELLO_DYNAMIC): examples/hello_dynamic.c | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 $< -o $@

$(HELLO_DYNAMIC_STRIPPED): $(HELLO_DYNAMIC)
	cp $< $@
	strip --strip-all $@

$(BENIGN_CONTROL): examples/benign_control.c | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 $< -o $@

$(HELLO_STATIC_OBJ): examples/hello_static.asm | $(BUILD_STAMP)
	$(ASM) -f elf64 $< -o $@

$(HELLO_STATIC): $(HELLO_STATIC_OBJ)
	$(LD) -static -o $@ $<

$(HELLO_STATIC_PIE): $(HELLO_STATIC_OBJ)
	$(LD) -pie --no-dynamic-linker -e _start -o $@ $<

$(HELLO_WX): $(HELLO_STATIC)
	cp $< $@
	printf '\007\000\000\000' | dd of=$@ bs=1 seek=124 conv=notrunc status=none

$(HELLO_DEPENDENCY): examples/hello_dependency.c examples/hello_dependency.map | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 -fpic -shared $< -Wl,--version-script,examples/hello_dependency.map -o $@

$(HELLO_WITH_DEPENDENCY): examples/hello_with_dependency.c $(HELLO_DEPENDENCY) | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 $< -L$(BUILD) -lhello_dependency -Wl,-rpath,'$$ORIGIN' -o $@

$(WRONG_DEPENDENCY): examples/wrong_dependency.c examples/wrong_dependency.map | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 -fpic -shared $< -Wl,--version-script,examples/wrong_dependency.map -Wl,-soname,libwrong_dependency.so -o $@

$(WRONG_PLACEHOLDER): examples/wrong_placeholder.c examples/wrong_dependency.map | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 -fpic -shared $< -Wl,--version-script,examples/wrong_dependency.map -Wl,-soname,libwrong_dependency.so -o $@

$(VERSIONED_DEPENDENCY): examples/versioned_dependency.c $(WRONG_PLACEHOLDER) $(WRONG_DEPENDENCY) $(HELLO_DEPENDENCY) | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 $< -L$(BUILD) -Wl,--no-as-needed -lwrong_placeholder -lhello_dependency -Wl,-rpath,'$$ORIGIN' -o $@

$(UNKNOWN_LD): | $(BUILD_STAMP)
	mkdir -p $(dir $@)
	cp /lib64/ld-linux-x86-64.so.2 $@
	printf '\014' | dd of=$@ bs=1 seek=728 conv=notrunc status=none

$(UNKNOWN_GLIBC): examples/hello_dynamic.c $(UNKNOWN_LD) | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 $< -Wl,--dynamic-linker,$(UNKNOWN_LD) -o $@

$(IFUNC_DEPENDENCY): examples/ifunc_dependency.c | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 -fpic -shared $< -o $@

$(IFUNC_PROGRAM): examples/ifunc_program.c $(IFUNC_DEPENDENCY) | $(BUILD_STAMP)
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 $< -L$(BUILD) -lifunc_dependency -Wl,-rpath,'$$ORIGIN' -o $@

$(MUSL_DEPENDENCY): examples/hello_dependency.c examples/hello_dependency.map | $(BUILD_STAMP)
	musl-gcc -std=c11 -Wall -Wextra -Werror -O2 -fpic -shared $< -Wl,--version-script,examples/hello_dependency.map -Wl,-soname,libhello_musl.so -o $@

$(MUSL_WITH_DEPENDENCY): examples/hello_with_dependency.c $(MUSL_DEPENDENCY) | $(BUILD_STAMP)
	musl-gcc -std=c11 -Wall -Wextra -Werror -O2 $< -L$(BUILD) -lhello_musl -Wl,-rpath,'$$ORIGIN' -o $@

$(MUSL_STATIC): examples/hello_dynamic.c | $(BUILD_STAMP)
	musl-gcc -static -std=c11 -Wall -Wextra -Werror -O2 $< -o $@

$(MUSL_STATIC_PIE): examples/hello_dynamic.c | $(BUILD_STAMP)
	musl-gcc -static-pie -std=c11 -Wall -Wextra -Werror -O2 $< -o $@

$(MUSL_STATIC_TLS): examples/static_tls.c | $(BUILD_STAMP)
	musl-gcc -static -std=c11 -Wall -Wextra -Werror -O2 $< -o $@

$(MUSL_STATIC_PIE_TLS): examples/static_tls.c | $(BUILD_STAMP)
	musl-gcc -static-pie -std=c11 -Wall -Wextra -Werror -O2 $< -o $@

run-c: build
	$(HARNESS) --script examples/math.fs --seed 1

run-py: build
	$(PY) harness/py_harness.py --script examples/math.fs --seed 1

inspect: build
	@wc -c $(SHELL_BIN)
	@readelf -r $(SHELL_OBJ)
	@readelf -S $(SHELL_OBJ)
	@objdump -d -M intel $(SHELL_OBJ) | sed -n '1,180p'

boundary-check:
	$(PY) tools/check_vm_boundary.py

packed-parity: build $(COMPILED_INSTRUMENTED)
	test "$$($(HARNESS) --blob $(DEV_BIN) --script examples/elf64_dryload.fs --seed 1 --rounds 2 --compile-only | grep 'forth_meta=')" = "$$($(HARNESS) --blob $(SHELL_BIN) --script $(COMPILED_INSTRUMENTED) --seed 1 --rounds 2 --compile-only | grep 'forth_meta=')"

compact-test: build
	$(HARNESS) --blob $(SHELL_BIN) --script $(COMPILED_PACKED) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_plan_summary=.*"maps":3'
	test "$$($(HARNESS) --blob $(SHELL_BIN) --script $(COMPILED_PACKED) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_plan_summary=')" = "$$($(HARNESS) --blob $(SHELL_BIN) --script $(COMPILED_INSTRUMENTED) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_plan_summary=')"
	$(HARNESS) --blob $(SHELL_BIN) --script $(COMPILED_PACKED) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_gnu_chain={"visited":0,"hash_matches":0,"name_exact_matches":0'
	$(HARNESS) --blob $(SHELL_BIN) --script $(COMPILED_PACKED) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --rounds 2 --forth-self-transfer | grep 'hello from imported dependency'

test: boundary-check packed-parity compact-test build
	$(PY) -c 'import tools.workspace_layout as w; assert w.validate_workspace_layout()[-1][1] + w.validate_workspace_layout()[-1][2] == w.WORKSPACE_SIZE'
	! $(HARNESS) --blob $(DEV_BIN) --input '2013 layout cell TOO-LARGE' --rounds 0 --compile-only
	! $(HARNESS) --blob $(DEV_BIN) --input '2012 layout 2 array TOO-LARGE' --rounds 0 --compile-only
	! $(HARNESS) --blob $(DEV_BIN) --input '0 layout 2 array A 1 layout' --rounds 0 --compile-only
	$(HARNESS) --blob $(DEV_BIN) --input '0 layout 2 array A 1 union cell B' --rounds 0 --compile-only | grep '"rc":0'
	$(HARNESS) --input '0 4096 3 1 osmap 0= . cr' --seed 1 | grep 'forth_output=0 '
	$(HARNESS) --input '0 4096 4 1 osmap 0= . cr' --seed 1 | grep 'forth_output=-1 '
	$(HARNESS) --input '65 0 p8! 0 p8@ . cr pbase drop' --seed 1 --rounds 2 | grep 'forth_output=65 '
	$(HARNESS) --input '0 0 cpuid . . . . cr' --seed 1 | grep '"final_depth":0'
	! $(HARNESS) --input '65 4096 p8!' --seed 1
	$(HARNESS) --script examples/source_read_smoke.fs --seed 1 --rounds 2 | grep 'forth_output=-1 '
	$(HARNESS) --script examples/source_read_smoke.fs --seed 1 --rounds 2 | grep '26936 '
	$(HARNESS) --script examples/source_read_smoke.fs --seed 1 --rounds 2 | grep '1179403647 '
	! $(HARNESS) --input '1 esource' --seed 1
	$(HARNESS) --input '2 3 + . cr' --seed 1 | grep 'forth_output=5 '
	$(PY) harness/py_harness.py --input '2 3 + . cr' --seed 1 | grep 'forth_output=5 '
	$(HARNESS) --input '2 3 + . cr' --seed 1 --rounds 2 | grep '"rounds_done":2'
	$(PY) harness/py_harness.py --input '2 3 + . cr' --seed 1 --rounds 2 | grep '"rounds_done":2'
	$(HARNESS) --script examples/stack.fs --seed 2 | grep 'forth_meta='
	$(HARNESS) --script examples/math.fs --seed 1 | grep '"validate_status":1'
	$(HARNESS) --script examples/math.fs --seed 1 --dump-tokens | grep 'trace_event='
	$(HARNESS) --script examples/math.fs --seed 1 --dump-tokens | grep 'trace_event=.*"event":4'
	$(HARNESS) --script examples/math.fs --seed 5 --dump-tokens | grep 'trace_event=.*"event":5'
	$(HARNESS) --script examples/math.fs --seed 2 --dump-tokens | grep 'trace_event=.*"event":6'
	$(HARNESS) --script examples/math.fs --seed 1 --dump-tokens | grep 'trace_event=.*"event":7'
	$(HARNESS) --script examples/math.fs --seed 1 --dump-tokens | grep 'trace_event=.*"event":8'
	$(HARNESS) --script examples/math.fs --seed 6 --dump-tokens | grep 'trace_event=.*"event":9'
	$(HARNESS) --input '0 . cr' --seed 1 --dump-tokens | grep 'trace_event=.*"event":10'
	$(HARNESS) --script examples/math.fs --seed 2 --dump-tokens | grep 'trace_event=.*"event":11'
	$(HARNESS) --script examples/math.fs --seed 2 --dump-tokens | grep 'trace_event=.*"event":12'
	$(HARNESS) --script examples/math.fs --seed 1 --dump-tokens | grep 'trace_event=.*"event":13'
	$(HARNESS) --script examples/math.fs --seed 1 --dump-tokens | grep 'trace_event=.*"event":14'
	$(HARNESS) --input '5 negate . cr' --seed 1 | grep 'forth_output=-5 '
	$(HARNESS) --input '0 0= . cr 4 1+ . cr 4 1- . cr 5 invert invert . cr 6 2* . cr' --seed 1 | grep 'forth_output=-1 '
	$(HARNESS) --input '6 3 and . cr 6 1 or . cr 6 3 xor . cr 1 4 lshift . cr 16 2 rshift . cr 1 2 u< . cr -1 1 u> . cr 7 4 min . cr 7 4 max . cr' --seed 1 | grep 'forth_output=2 '
	$(HARNESS) --input '42 3 m! 3 m@ . cr 20 4 u/ . cr' --seed 1 --rounds 2 | grep 'forth_output=42 '
	$(HARNESS) --input '64 constant PHOFF PHOFF . cr 5 constant PF-X 6 PF-X and . cr' --seed 1 | grep 'forth_output=64 '
	$(HARNESS) --input ': sq dup * ; 7 sq . cr : add3 3 + ; 4 add3 . cr' --seed 1 | grep 'forth_output=49 '
	$(HARNESS) --input '2 constant ELFCLASS64 : t ELFCLASS64 ; t . cr' --seed 1 | grep 'forth_output=2 '
	$(HARNESS) --input '3 for i . cr next' --seed 1 | grep 'forth_output=0 '
	$(HARNESS) --input '3 for i 1 + . cr next' --seed 1 --rounds 2 | grep '"validate_status":1'
	$(HARNESS) --input '3 for i 1 + . cr next' --seed 1 --rounds 2 | grep '"rounds_done":2'
	$(HARNESS) --input '1 if 10 . cr else 20 . cr then 0 if 30 . cr else 40 . cr then' --seed 2 --rounds 2 | grep 'forth_output=10 '
	$(HARNESS) --input '3 for i 1 = if 99 . cr else i . cr then next' --seed 3 --rounds 2 | grep '"validate_status":1'
	$(PY) harness/py_harness.py --input '3 for i . cr next' --seed 1 | grep 'forth_output=0 '
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 | grep '"validate_status":1'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 | grep '"rounds_done":2'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record=.*"owned":true'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record={"index":1.*"owned":true'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record={"index":1.*"relative_applied":11'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record={"index":1.*"required_unresolved":1.*"required_symbol":0'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record={"index":1.*"irelative_target":222048.*"irelative_resolver":108752'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record={"index":2.*"strtab":[1-9].*"symtab":[1-9].*"gnu_hash":[1-9].*"syment":24'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record={"index":0.*"resolved":3'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record={"index":0.*"required_unresolved":0'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record={"index":2.*"resolved":85'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record={"index":2.*"verdef":[1-9].*"verdefnum":[1-9]'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_gnu_chain=.*"name_exact_matches":85'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_discovery_pass={"object":2.*"state":18446744073709551615'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_plan_summary=.*"maps":3'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_service={"name":"read_file_dedup".*"existing":1'
	$(HARNESS) --elf-forth /bin/ls --seed 1 --real-forth-mappings | grep 'forth_service={"name":"read_file","slot":4.*libpcre2'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_service={"name":"read_file","slot":2.*libhello_dependency'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_service={"name":"read_file","slot":3.*libc.so.6'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_plan_summary=.*"maps":4'
	readelf -d $(VERSIONED_DEPENDENCY) | grep -A1 'NEEDED.*libwrong_dependency.so' | grep 'libhello_dependency.so'
	readelf -V $(VERSIONED_DEPENDENCY) | grep 'HELLO_1.0'
	readelf -V $(WRONG_DEPENDENCY) | grep 'HELLO_2.0'
	$(HARNESS) --elf-forth $(VERSIONED_DEPENDENCY) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_plan_summary=.*"maps":5'
	$(HARNESS) --elf-forth $(VERSIONED_DEPENDENCY) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record={"index":0.*"resolved":5.*"required_unresolved":0'
	$(HARNESS) --elf-forth $(VERSIONED_DEPENDENCY) --seed 1 --rounds 2 --forth-transfer | grep 'hello from imported dependency'
	! $(HARNESS) --elf-forth $(VERSIONED_DEPENDENCY) --seed 1 --rounds 2 --forth-transfer | grep 'wrong version selected'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_link_summary=.*"adapter":1'
	! $(HARNESS) --elf-forth $(UNKNOWN_GLIBC) --seed 1 --rounds 2 --real-forth-mappings --forth-self-transfer
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --forth-self-link | grep 'forth_link_summary=.*"native_calls":47.*"native_pending":0.*"native_results":45'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --forth-self-link | grep 'forth_object_record={"index":2.*"required_unresolved":0'
	$(HARNESS) --elf-forth $(IFUNC_PROGRAM) --seed 1 --rounds 2 --forth-self-link | grep 'forth_link_summary=.*"ifunc_calls":1.*"ifunc_result":[1-9]'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --rounds 2 --forth-self-link | grep 'forth_link_summary=.*"native_pending":0.*"constructors":8'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --rounds 2 --forth-self-link | awk '/dependency constructor ran/{d=NR} /main constructor ran/{m=NR} END {exit !(d && m && d < m)}'
	! $(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --rounds 2 --forth-self-link | grep 'dependency TLS template failed'
	$(HARNESS) --elf-forth $(MUSL_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_service={"name":"read_file","slot":1.*ld-musl'
	$(HARNESS) --elf-forth $(MUSL_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_service={"name":"read_file_dedup".*"existing":1'
	$(HARNESS) --elf-forth $(MUSL_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_plan_summary=.*"maps":3'
	$(HARNESS) --elf-forth $(MUSL_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_object_record={"index":1.*"required_unresolved":0'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_object_record={"index":0.*"required_unresolved":0'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_object_record={"index":2.*"tls_memsz":8.*"tls_align":4'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record={"index":2.*"tls_filesz":4.*"tls_memsz":8'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_object_record={"index":3.*"tls_offset":8.*"tls_module":4'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_link_summary=.*"tls_total":144.*"tls_base":[1-9]'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_link_summary=.*"tcb_base":[1-9]'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_tls_control=.*"stack_guard":[1-9].*"generation":1.*"dtv_ok":true'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_service={"name":"copy".*"bytes":16'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_service={"name":"copy".*"bytes":8'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_service={"name":"copy".*"bytes":192'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_object_record={"index":2.*"init_array":[1-9].*"init_arraysz":16'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --real-forth-mappings | grep 'forth_object_record={"index":0.*"verneed":[1-9].*"verneednum":[1-9]'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_link_summary={"phase":1.*"gnu_candidates":[1-9].*,"nonempty_buckets":[1-9]'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_link_summary=.*"first_hash_matches":[1-9]'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_gnu_chain={"visited":[1-9].*,"hash_matches":[1-9]'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_gnu_chain=.*"name_exact_matches":[1-9]'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_gnu_chain=.*"resolved":[1-9]'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_gnu_chain=.*"resolved":85'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_gnu_chain=.*"segments_protected":[1-9]'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_service={"name":"protect".*"prot":5,"exec":true'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_service={"name":"protect".*"prot":1,"exec":false'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_plan_summary=.*"real_mappings":true.*"transferred":false'
	$(HARNESS) --elf-forth $(HELLO_STATIC) --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record=.*"final_base":0x400000.*"owned":true'
	$(HARNESS) --elf-forth $(HELLO_STATIC) --seed 1 --rounds 2 --forth-transfer | grep 'hello from static demo elf'
	$(HARNESS) --elf-forth $(HELLO_STATIC_PIE) --seed 1 --rounds 2 --forth-transfer | grep 'hello from static demo elf'
	$(HARNESS) --elf-forth $(MUSL_STATIC) --seed 1 --rounds 2 --forth-self-transfer | grep 'hello from dynamic demo elf'
	$(HARNESS) --elf-forth $(MUSL_STATIC_PIE) --seed 1 --rounds 2 --forth-self-transfer | grep 'hello from dynamic demo elf'
	$(HARNESS) --elf-forth $(MUSL_STATIC_TLS) --seed 1 --rounds 2 --forth-self-transfer | grep 'static TLS template ready'
	$(HARNESS) --elf-forth $(MUSL_STATIC_PIE_TLS) --seed 1 --rounds 2 --forth-self-transfer | grep 'static TLS template ready'
	! $(HARNESS) --elf-forth $(MUSL_WITH_DEPENDENCY) --forth-self-transfer
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --forth-self-transfer | grep 'hello from dynamic demo elf'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --forth-self-transfer | grep '^build/hello_dynamic$$'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --forth-self-transfer | grep 'forth_entry_transfer={"kind":"program"'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --rounds 2 --forth-self-transfer | grep 'dependency constructor ran'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --rounds 2 --forth-self-transfer | grep 'hello from imported dependency'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --rounds 2 --forth-self-transfer | grep 'dependency TLS ready'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --rounds 2 --forth-self-transfer --forth-arg stack-marker | grep '^stack-marker$$'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --seed 1 --rounds 2 --forth-self-transfer --forth-env FORTH_MARKER=environment-marker | grep '^environment-marker$$'
	readelf -V $(HELLO_WITH_DEPENDENCY) | grep 'HELLO_1.0'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC) --seed 1 --rounds 2 --forth-transfer | grep 'forth_plan_summary=.*"maps":2'
	$(HARNESS) --elf-forth $(HELLO_DYNAMIC_STRIPPED) --seed 1 --rounds 2 --forth-self-transfer | grep 'hello from dynamic demo elf'
	! nm $(HELLO_DYNAMIC_STRIPPED) 2>&1 | grep 'main'
	$(HARNESS) --elf-forth-buffer-demo --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_elf_source=.*"kind":"memory_buffer"'
	$(HARNESS) --elf-forth-buffer-demo --seed 1 --rounds 2 --real-forth-mappings | grep 'forth_object_record=.*"owned":true'
	$(HARNESS) --elf-forth-buffer-demo --seed 1 --rounds 2 --forth-transfer | grep 'hello from memory-only elf'
	$(PY) harness/py_harness.py --elf-forth $(HELLO_DYNAMIC) --seed 1 | grep '"validate_status":1'
	! $(HARNESS) --input 'drop' --seed 1
	! $(HARNESS) --input '0 0 ocall' --seed 1
	$(PY) tools/run_matrix.py --harness $(HARNESS) --script examples/math.fs --seeds 1,2,3,4,5
	$(PY) tools/run_matrix.py --harness $(HARNESS) --script examples/math.fs --seeds 1,2,3 --rounds 2
	$(HARNESS) --script examples/math.fs --seed 3 --payload print | grep 'payload_report=.*"kind":"print"'
	$(HARNESS) --script examples/math.fs --seed 3 --payload cat-fixture | grep 'Stage 2.5 fixture line one'
	$(HARNESS) --script examples/math.fs --seed 3 --payload spawn-id | grep 'payload_report=.*"kind":"spawn_id".*"shell":false'
	$(HARNESS) --script examples/math.fs --seed 3 --payload all | grep '^uid='
	$(HARNESS) --script examples/math.fs --seed 7 --elf /bin/true | grep 'elf_dynamic=.*"relocation_required":true'
	$(HARNESS) --script examples/math.fs --seed 7 --elf /bin/true | grep 'elf_relocations=.*"relative_applied":'
	$(HARNESS) --script examples/math.fs --seed 7 --elf /bin/true | grep 'elf_entry_transfer=.*"transferred":false'
	$(HARNESS) --script examples/math.fs --seed 7 --elf /bin/true | grep 'elf_report=.*"entry_in_load":true.*"execution":"not_transferred"'
	$(HARNESS) --script examples/math.fs --seed 7 --elf /bin/true | grep 'elf_segment=.*"bss":'
	$(HARNESS) --script examples/math.fs --seed 7 --elf /bin/true | grep 'elf_image=.*"anonymous_nonexec_rw"'

	$(HARNESS) --script examples/math.fs --seed 7 --elf build/hello_dynamic --elf-exec-protections | grep 'elf_protect=.*"exec":true.*"transferred":false'
	$(HARNESS) --script examples/math.fs --seed 7 --elf build/hello_dynamic --elf-exec-protections --ld-dry-runs 2 | grep 'elf_ld_dry_run=.*"run":2'
	$(HARNESS) --script examples/math.fs --seed 7 --elf build/hello_dynamic --elf-exec-protections --ld-dry-runs 2 | grep 'elf_source=.*"kind":"ld_interpreter"'
	$(HARNESS) --script examples/math.fs --seed 7 --elf-buffer-demo | grep 'elf_source=.*"kind":"memory_buffer"'
	$(HARNESS) --script examples/math.fs --seed 7 --elf-buffer-demo | grep 'elf_report=.*"has_interp":false.*"execution":"not_transferred"'
	$(HARNESS) --script examples/math.fs --seed 7 --elf /bin/true --elf-buffer-demo | grep 'elf_source=.*"kind":"disk"'
	$(HARNESS) --script examples/math.fs --seed 7 --elf /bin/true --elf-buffer-demo | grep 'elf_source=.*"kind":"memory_buffer"'
	$(HELLO_DYNAMIC) | grep 'hello from dynamic demo elf'
	$(HELLO_STATIC) | grep 'hello from static demo elf'
	$(BENIGN_CONTROL) | grep 'benign-control'
	readelf -l $(HELLO_DYNAMIC) | grep 'INTERP'
	! readelf -l $(HELLO_STATIC) | grep 'INTERP'
	$(HARNESS) --script examples/math.fs --seed 7 --elf $(HELLO_DYNAMIC) | grep 'elf_report=.*"has_interp":true.*"execution":"not_transferred"'
	$(HARNESS) --script examples/math.fs --seed 7 --elf $(HELLO_DYNAMIC) | grep 'elf_initial_stack=.*"auxv_base_required":true'
	$(HARNESS) --script examples/math.fs --seed 7 --elf $(HELLO_STATIC) | grep 'elf_report=.*"has_interp":false.*"has_dynamic":false.*"execution":"not_transferred"'
	$(HARNESS) --script examples/math.fs --seed 7 --elf $(HELLO_STATIC) | grep 'elf_relocations=.*"resolver_needed":false'
	readelf -r $(SHELL_OBJ) | grep 'There are no relocations in this file.'

callable-test: build
	$(HARNESS) --script examples/callable_words.fs --callable-words --rounds 2 | grep 'forth_output=81 '
	$(HARNESS) --script examples/callable_words.fs --callable-words --rounds 2 | grep '^3 '
	$(HARNESS) --script examples/callable_words.fs --callable-words --rounds 2 | grep '"word_rounds_done":2'
	test "$$($(HARNESS) --input ': twice 1 + ; 2 twice twice . cr' --callable-words --rounds 2 --seed 2 --dump-tokens | grep -c '^word_body=')" -eq 1
	test "$$($(HARNESS) --input ': twice 1 + ; 2 twice twice . cr' --callable-words --rounds 2 --seed 2 --dump-tokens | grep -c 'orig_token=.*\"op\":82')" -eq 2
	$(HARNESS) --input ': twice 1 + ; 2 twice twice . cr' --callable-words --rounds 2 --seed 2 --dump-tokens | grep 'word_body=.*"polymorphic_tokens":[1-9]'
	$(HARNESS) --input ': twice 1 + ; 2 twice twice . cr' --callable-words --rounds 2 --seed 2 --dump-tokens | grep 'word_body={"word":0,"tokens":5'
	$(HARNESS) --input ': choose dup 0= if drop 41 else drop 42 then ; 0 choose . 1 choose . cr' --rounds 2 --seed 3 --dump-tokens | grep 'forth_output=41 42 '
	$(HARNESS) --input ': sum 0 swap for i + next ; 4 sum . cr' --rounds 2 --seed 2 --dump-tokens | grep 'forth_output=6 '
	! $(HARNESS) --input ': recurse recurse ; 1 recurse' --callable-words --rounds 1 | grep '"rc":0'
	$(HARNESS) --input '0 0 0 0 0 0 39 syscall6 0 > . cr' --callable-words --rounds 2 | grep 'forth_output=-1 '

syscall-test: build
	$(HARNESS) --input '0 4096 3 1 osmap dup 4096 1 osprot . cr dup 4096 osunmap . cr drop' --callable-words --syscall-services --rounds 2 | grep -A1 'forth_output=0 ' | grep '^0 '
	! $(HARNESS) --elf-forth $(HELLO_STATIC) --callable-words --syscall-services --rounds 2 --real-forth-mappings | grep 'forth_service={"name":"map"'
	$(HARNESS) --elf-forth $(HELLO_STATIC) --callable-words --syscall-services --rounds 2 --real-forth-mappings | grep 'forth_meta={"rc":0.*"rounds_done":2'
	! $(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --callable-words --syscall-services --rounds 2 --real-forth-mappings | grep 'forth_service={"name":"read_file"'
	$(HARNESS) --elf-forth $(HELLO_WITH_DEPENDENCY) --callable-words --syscall-services --rounds 2 --real-forth-mappings | grep 'forth_link_summary=.*"native_pending":0'
	! $(HARNESS) --forth-bootstrap-path $(HELLO_DYNAMIC) --rounds 2 | grep 'forth_service={"name":"read_file"'
	$(HARNESS) --forth-bootstrap-path $(HELLO_DYNAMIC) --rounds 2 | grep 'forth_discovery_pass=.*"state":18446744073709551615'
	$(STANDALONE_LAUNCHER) $(SHELL_BIN) $(HELLO_STATIC) | grep 'hello from static demo elf'

standalone-test: build $(HELLO_WX)
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(HELLO_STATIC) | grep 'hello from static demo elf'
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(HELLO_STATIC_PIE) | grep 'hello from static demo elf'
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(MUSL_STATIC) | grep 'hello from dynamic demo elf'
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(MUSL_STATIC_PIE) | grep 'hello from dynamic demo elf'
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(MUSL_STATIC_TLS) | grep 'static TLS template ready'
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(MUSL_STATIC_PIE_TLS) | grep 'static TLS template ready'
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(HELLO_DYNAMIC) | grep 'hello from dynamic demo elf'
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(HELLO_WITH_DEPENDENCY) | grep 'hello from imported dependency'
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(VERSIONED_DEPENDENCY) | grep 'hello from imported dependency'
	! $(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(VERSIONED_DEPENDENCY) | grep 'wrong version selected'
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(IFUNC_PROGRAM) | grep 'IFUNC fixture ready'
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(HELLO_WITH_DEPENDENCY) stack-marker | grep '^stack-marker$$'
	FORTH_MARKER=environment-marker $(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(HELLO_WITH_DEPENDENCY) | grep '^environment-marker$$'
	readelf -r $(STANDALONE_OBJ) | grep 'There are no relocations in this file.'
	test -z "$$(nm -u $(STANDALONE_OBJ))"
	! $(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(UNKNOWN_GLIBC)
	! $(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(MUSL_WITH_DEPENDENCY)
	! $(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(HELLO_WX)
	! $(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(BUILD)/does-not-exist
	$(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(BUILD)/does-not-exist 2>&1 | grep 'forth-loader: rejected'

embedded-static-test: $(EMBEDDED_STATIC) $(EMBEDDED_STATIC_PIE) $(EMBEDDED_GO_STATIC) $(STANDALONE_LAUNCHER) $(FIXED_STANDALONE_LAUNCHER) $(AUDIT_STANDALONE_LAUNCHER) $(HELLO_WX)
	$(PY) tools/test_embedded_static.py
	! $(PY) tools/pack_standalone.py $(EMBEDDED_BIN) $(HELLO_DYNAMIC) /tmp/embedded-dynamic.bundle
	! $(PY) tools/pack_standalone.py $(EMBEDDED_BIN) $(HELLO_WX) /tmp/embedded-wx.bundle
	readelf -r $(EMBEDDED_OBJ) | grep 'There are no relocations in this file.'
	test -z "$$(nm -u $(EMBEDDED_OBJ))"

ruby-perl-runner-test: $(EMBEDDED_STATIC_PIE) $(EMBEDDED_GO_STATIC) $(SIGNAL_STATIC_PIE) $(SIGNAL_GO_STATIC)
	$(PY) tools/test_ruby_perl_runners.py
	! $(PY) tools/pack_standalone.py --signal-entry $(SIGNAL_GO_STATIC) $(GO_STATIC) /tmp/double-signal.bundle
	! $(PY) tools/pack_standalone.py --signal-entry $(EMBEDDED_BIN) $(HELLO_DYNAMIC) /tmp/embedded-dynamic-signal.bundle

demo-test: build
	$(PY) tools/pack_standalone.py $(EMBEDDED_BIN) $(HELLO_STATIC_PIE) $(BUILD)/demo.bundle
	$(PY) harness/py_harness.py --embedded $(BUILD)/demo.bundle --embedded-raw | grep 'hello from static demo elf'
	$(STANDALONE_LAUNCHER) --embedded-raw $(BUILD)/demo.bundle | grep 'hello from static demo elf'
	$(PY) tools/pack_standalone.py --signal-entry $(EMBEDDED_BIN) $(HELLO_STATIC_PIE) $(BUILD)/demo.signal.bundle
	perl harness/perl_harness.pl --embedded-signal $(BUILD)/demo.signal.bundle | grep 'hello from static demo elf'
	$(PY) tools/run_matrix.py --harness $(HARNESS) --script examples/math.fs --seeds 1,2,3 --rounds 2

probe-test: build
	@echo '{"pid":1,"phase":"load_shellcode_blob"}' > $(BUILD)/marker_only.jsonl
	@echo '{"pid":1,"phase":"prepare_exec_mapping"}' >> $(BUILD)/marker_only.jsonl
	@echo '{"pid":1,"phase":"invoke_forth_blob","transforms":3}' >> $(BUILD)/marker_only.jsonl
	! $(PY) detections/rules.py $(BUILD)/marker_only.jsonl
	@echo '{"pid":2,"ts_ns":100,"event":"mmap","length":4096,"prot":"rw","flags":34}' > $(BUILD)/behavior_sample.jsonl
	@echo '{"pid":2,"ts_ns":200,"event":"mprotect","length":4096,"prot":"rx"}' >> $(BUILD)/behavior_sample.jsonl
	$(PY) detections/rules.py $(BUILD)/behavior_sample.jsonl
	@echo '{"pid":5,"ts_ns":100,"event":"openat","path":"examples/payload_fixture.txt","flags":0}' > $(BUILD)/benign_control_sample.jsonl
	@echo '{"pid":5,"ts_ns":110,"event":"read","fd":3,"count":128}' >> $(BUILD)/benign_control_sample.jsonl
	@echo '{"pid":5,"ts_ns":120,"event":"mmap","addr":8192,"length":4096,"prot":"rw","flags":34}' >> $(BUILD)/benign_control_sample.jsonl
	@echo '{"pid":5,"ts_ns":130,"event":"munmap","addr":8192,"length":4096}' >> $(BUILD)/benign_control_sample.jsonl
	! $(PY) detections/rules.py $(BUILD)/benign_control_sample.jsonl
	@echo '{"pid":3,"ts_ns":100,"event":"mmap","addr":4096,"length":4096,"prot":"rw","flags":34}' > $(BUILD)/payload_behavior_sample.jsonl
	@echo '{"pid":3,"ts_ns":200,"event":"mprotect","addr":4096,"length":4096,"prot":"rx"}' >> $(BUILD)/payload_behavior_sample.jsonl
	@echo '{"pid":3,"ts_ns":300,"event":"openat","path":"examples/payload_fixture.txt","flags":0}' >> $(BUILD)/payload_behavior_sample.jsonl
	@echo '{"pid":3,"ts_ns":350,"event":"munmap","addr":4096,"length":4096}' >> $(BUILD)/payload_behavior_sample.jsonl
	@echo '{"pid":3,"ts_ns":360,"event":"openat","path":"/lib64/ld-linux-x86-64.so.2","flags":0}' >> $(BUILD)/payload_behavior_sample.jsonl
	@echo '{"pid":3,"ts_ns":370,"event":"openat","path":"/lib64/ld-linux-x86-64.so.2","flags":0}' >> $(BUILD)/payload_behavior_sample.jsonl
	@echo '{"pid":4,"ts_ns":400,"event":"execve","path":"/usr/bin/id"}' >> $(BUILD)/payload_behavior_sample.jsonl
	$(PY) detections/rules.py $(BUILD)/payload_behavior_sample.jsonl | grep 'executable_anonymous_memory_with_file_io'
	$(PY) detections/rules.py $(BUILD)/payload_behavior_sample.jsonl | grep 'executable_anonymous_memory_lifecycle'
	$(PY) detections/rules.py $(BUILD)/payload_behavior_sample.jsonl | grep 'repeated_dynamic_linker_activity_near_executable_memory'
	$(PY) detections/rules.py $(BUILD)/payload_behavior_sample.jsonl | grep 'process_exec_near_executable_anonymous_memory'
	@echo 'Run live behavior probes with: sudo $(PY) tools/probe_bcc.py --binary $(HARNESS) -- $(HARNESS) --script examples/math.fs --rounds 2 --payload all --elf build/hello_dynamic --elf-exec-protections --ld-dry-runs 2'
	@echo 'Optional debug markers: sudo $(PY) tools/probe_bcc.py --lab-markers --binary $(HARNESS) -- $(HARNESS) --script examples/math.fs --rounds 2 --payload all --elf build/hello_dynamic --elf-exec-protections --ld-dry-runs 2'

matrix-test: build
	$(PY) tools/run_glibc_matrix.py --harness $(HARNESS) --launcher $(STANDALONE_LAUNCHER) --blob $(STANDALONE_BIN)

standalone-audit: test callable-test syscall-test standalone-test matrix-test
	test "$$($(HARNESS) --script examples/elf64_dryload.fs --rounds 2 --compile-only | awk -F'[:,]' '/forth_meta=/{for(i=1;i<=NF;i++)if($$i~/original_tokens/)a=$$(i+1);for(i=1;i<=NF;i++)if($$i~/word_tokens/)b=$$(i+1)}END{gsub(/[^0-9]/,"",a);gsub(/[^0-9]/,"",b);print a+b}')" -le 6000
	for i in 1 2 3 4; do FORTH_MARKER=randomized-$$i $(STANDALONE_LAUNCHER) $(STANDALONE_BIN) $(HELLO_WITH_DEPENDENCY) stack-$$i | grep "stack-$$i" >/dev/null; done
	readelf -r $(STANDALONE_OBJ) | grep 'There are no relocations in this file.'
	test -z "$$(nm -u $(STANDALONE_OBJ))"

probe-live: build
	sudo $(PY) tools/probe_bcc.py --binary $(HARNESS) --output $(PROBE_EVENTS) -- $(HARNESS) --script examples/math.fs --rounds 2 --payload all --elf $(HELLO_DYNAMIC) --elf-exec-protections --ld-dry-runs 2
	$(PY) detections/rules.py $(PROBE_EVENTS) > $(PROBE_FINDINGS)
	@cat $(PROBE_FINDINGS)

probe-control: build
	sudo $(PY) tools/probe_bcc.py --binary $(HARNESS) --output $(CONTROL_EVENTS) -- $(BENIGN_CONTROL)
	! $(PY) detections/rules.py $(CONTROL_EVENTS)

clean:
	rm -rf $(BUILD)
