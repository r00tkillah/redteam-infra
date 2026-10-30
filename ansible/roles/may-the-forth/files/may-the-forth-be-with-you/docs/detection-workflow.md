# Detection Workflow

The detection workflow has three layers:

1. Generate local behavior with the harness.
2. Capture kernel/user-space telemetry with BCC.
3. Correlate JSONL events with `detections/rules.py`.

## Probe Collector

`tools/probe_bcc.py` captures:

- `mmap` via kprobe/kretprobe, including return address,
- `mprotect`,
- `munmap`,
- `openat`,
- `read`,
- `execve`.

When it launches a command, it filters to that process tree by default using PID/PPID tracking. Use `--all-pids` for system-wide capture.

Use `--output` to write JSONL while also printing events:

```sh
sudo python3 tools/probe_bcc.py \
  --binary build/c_harness \
  --output build/probe_events.jsonl \
  -- build/c_harness --script examples/math.fs --rounds 2 --payload all \
     --elf build/hello_dynamic --elf-exec-protections --ld-dry-runs 2
```

The Forth-plan mapping path is also useful detector stimulus because final mappings and protections are driven by the polymorphically executed Forth loader plan:

```sh
sudo python3 tools/probe_bcc.py \
  --binary build/c_harness \
  --output build/probe_events.jsonl \
  -- build/c_harness --elf-forth build/hello_dynamic --rounds 2 --real-forth-mappings
```

For static ELF behavior from a memory buffer:

```sh
sudo python3 tools/probe_bcc.py \
  --binary build/c_harness \
  --output build/probe_events.jsonl \
  -- build/c_harness --elf-forth-buffer-demo --rounds 2 --real-forth-mappings
```

## Correlation Rules

Run:

```sh
python3 detections/rules.py build/probe_events.jsonl
```

Current rules detect:

- anonymous RW memory made executable,
- executable anonymous memory with file I/O,
- executable anonymous memory lifecycle including `munmap`,
- repeated dynamic-linker activity near executable anonymous memory,
- process exec near executable anonymous memory.

The rules intentionally ignore lab-only markers. Optional uprobes can explain a run, but findings should be driven by behavior.

## Make Targets

Synthetic rule checks:

```sh
make probe-test
```

Live harness capture and correlation:

```sh
make probe-live
```

Live benign control:

```sh
make probe-control
```

The benign control does ordinary file I/O and anonymous RW mapping, but it does not create executable anonymous memory. The correlated rules should not fire.

## Marker Policy

`tools/probe_bcc.py --lab-markers` attaches optional uprobes to stable harness functions. These are useful for debugging and timeline annotation, but detection rules must not depend on them.

This is deliberate: detections should generalize to behavior outside the lab harness.
