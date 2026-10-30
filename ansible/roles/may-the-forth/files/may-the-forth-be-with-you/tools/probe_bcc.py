#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
import time

try:
    from bcc import BPF
except Exception as exc:  # pragma: no cover - depends on host privileges/packages
    BPF = None
    BCC_IMPORT_ERROR = exc
else:
    BCC_IMPORT_ERROR = None


BPF_PROGRAM = r"""
#include <uapi/linux/ptrace.h>
#include <linux/sched.h>

struct event_t {
    u64 ts;
    u32 pid;
    u32 tid;
    u32 ppid;
    u32 kind;
    u64 a0;
    u64 a1;
    u64 a2;
    char name[80];
};

struct mmap_args_t {
    u64 length;
    u64 prot;
    u64 flags;
};

BPF_PERF_OUTPUT(events);
BPF_HASH(active_mmap, u64, struct mmap_args_t);

static int submit(struct pt_regs *ctx, u32 kind, u64 a0, u64 a1, u64 a2) {
    struct event_t e = {};
    u64 id = bpf_get_current_pid_tgid();
    struct task_struct *task = (struct task_struct *)bpf_get_current_task();
    e.ts = bpf_ktime_get_ns();
    e.pid = id >> 32;
    e.tid = (u32)id;
    e.ppid = task->real_parent->tgid;
    e.kind = kind;
    e.a0 = a0;
    e.a1 = a1;
    e.a2 = a2;
    events.perf_submit(ctx, &e, sizeof(e));
    return 0;
}

static int submit_path(struct pt_regs *ctx, u32 kind, const char *path, u64 a0, u64 a1, u64 a2) {
    struct event_t e = {};
    u64 id = bpf_get_current_pid_tgid();
    struct task_struct *task = (struct task_struct *)bpf_get_current_task();
    e.ts = bpf_ktime_get_ns();
    e.pid = id >> 32;
    e.tid = (u32)id;
    e.ppid = task->real_parent->tgid;
    e.kind = kind;
    e.a0 = a0;
    e.a1 = a1;
    e.a2 = a2;
    bpf_probe_read_user_str(&e.name, sizeof(e.name), path);
    events.perf_submit(ctx, &e, sizeof(e));
    return 0;
}

int on_load(struct pt_regs *ctx) { return submit(ctx, 1, 0, 0, 0); }
int on_prepare(struct pt_regs *ctx) { return submit(ctx, 2, 0, 0, 0); }
int on_invoke(struct pt_regs *ctx) { return submit(ctx, 3, PT_REGS_PARM2(ctx), PT_REGS_PARM4(ctx), 0); }
int on_elf(struct pt_regs *ctx) { return submit(ctx, 4, 0, 0, 0); }

int on_mmap_enter(struct pt_regs *ctx) {
    u64 id = bpf_get_current_pid_tgid();
    struct mmap_args_t args = {};
    args.length = PT_REGS_PARM2(ctx);
    args.prot = PT_REGS_PARM3(ctx);
    args.flags = PT_REGS_PARM4(ctx);
    active_mmap.update(&id, &args);
    return 0;
}

int on_mmap_return(struct pt_regs *ctx) {
    u64 id = bpf_get_current_pid_tgid();
    struct mmap_args_t *args = active_mmap.lookup(&id);
    if (!args) return 0;
    u64 ret = PT_REGS_RC(ctx);
    submit(ctx, 10, ret, args->length, (args->flags << 32) | (args->prot & 0xffffffff));
    active_mmap.delete(&id);
    return 0;
}

int on_mprotect(struct pt_regs *ctx) {
    return submit(ctx, 11, PT_REGS_PARM1(ctx), PT_REGS_PARM2(ctx), PT_REGS_PARM3(ctx));
}

int on_openat(struct pt_regs *ctx) {
    return submit_path(ctx, 12, (const char *)PT_REGS_PARM2(ctx), PT_REGS_PARM3(ctx), PT_REGS_PARM1(ctx), 0);
}

int on_read(struct pt_regs *ctx) {
    return submit(ctx, 13, PT_REGS_PARM1(ctx), PT_REGS_PARM3(ctx), 0);
}

int on_execve(struct pt_regs *ctx) {
    return submit_path(ctx, 14, (const char *)PT_REGS_PARM1(ctx), 0, 0, 0);
}

int on_munmap(struct pt_regs *ctx) {
    return submit(ctx, 15, PT_REGS_PARM1(ctx), PT_REGS_PARM2(ctx), 0);
}
"""


KIND = {
    1: ("phase", "load_shellcode_blob"),
    2: ("phase", "prepare_exec_mapping"),
    3: ("phase", "invoke_forth_blob"),
    4: ("phase", "run_elf_mapping_sim"),
    10: ("event", "mmap"),
    11: ("event", "mprotect"),
    12: ("event", "openat"),
    13: ("event", "read"),
    14: ("event", "execve"),
    15: ("event", "munmap"),
}


def prot_string(bits: int) -> str:
    return "".join(ch for ch, mask in (("r", 1), ("w", 2), ("x", 4)) if bits & mask) or "-"


def event_to_row(cpu, data, size, bpf, started):
    e = bpf["events"].event(data)
    key, value = KIND.get(e.kind, ("event", f"kind_{e.kind}"))
    row = {
        "ts_ns": int(e.ts),
        "elapsed_ms": round((time.time() - started) * 1000, 3),
        "pid": int(e.pid),
        "tid": int(e.tid),
        "ppid": int(e.ppid),
        key: value,
    }
    if e.kind == 10:
        packed = int(e.a2)
        row.update({
            "addr": int(e.a0),
            "length": int(e.a1),
            "prot": prot_string(packed & 0xFFFFFFFF),
            "flags": (packed >> 32) & 0xFFFFFFFF,
        })
    elif e.kind == 11:
        row.update({"addr": int(e.a0), "length": int(e.a1), "prot": prot_string(int(e.a2))})
    elif e.kind == 12:
        row.update({"path": e.name.decode("utf-8", "replace").rstrip("\x00"), "flags": int(e.a0), "dirfd": int(e.a1)})
    elif e.kind == 13:
        row.update({"fd": int(e.a0), "count": int(e.a1)})
    elif e.kind == 14:
        row.update({"path": e.name.decode("utf-8", "replace").rstrip("\x00")})
    elif e.kind == 15:
        row.update({"addr": int(e.a0), "length": int(e.a1)})
    return row


class EventSink:
    def __init__(self, bpf, started, output_path: str | None, target_pid: int | None, all_pids: bool):
        self.bpf = bpf
        self.started = started
        self.target_pid = target_pid
        self.all_pids = all_pids
        self.pid_tree = {target_pid} if target_pid else set()
        self.output = open(output_path, "w", encoding="utf-8") if output_path else None

    def close(self) -> None:
        if self.output:
            self.output.close()

    def keep(self, row: dict) -> bool:
        if self.all_pids or self.target_pid is None:
            return True
        pid = int(row.get("pid", 0) or 0)
        ppid = int(row.get("ppid", 0) or 0)
        if pid in self.pid_tree or ppid in self.pid_tree:
            self.pid_tree.add(pid)
            return True
        return False

    def __call__(self, cpu, data, size):
        row = event_to_row(cpu, data, size, self.bpf, self.started)
        if not self.keep(row):
            return
        line = json.dumps(row, sort_keys=True)
        print(line, flush=True)
        if self.output:
            self.output.write(line + "\n")
            self.output.flush()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", default="build/c_harness")
    parser.add_argument("--output", "-o", help="write captured JSONL events to this file while also printing them")
    parser.add_argument("--all-pids", action="store_true",
                        help="do not filter to the launched command process tree")
    parser.add_argument("--lab-markers", action="store_true",
                        help="also attach uprobes to harness phase functions for debugging; detections must not depend on these")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command and args.command[0] == "--":
        args.command = args.command[1:]

    if BPF is None:
        print(f"BCC unavailable: {BCC_IMPORT_ERROR}", file=sys.stderr)
        return 2

    bpf = BPF(text=BPF_PROGRAM)
    if args.lab_markers:
        for sym, fn in [
            ("load_shellcode_blob", "on_load"),
            ("prepare_exec_mapping", "on_prepare"),
            ("invoke_forth_blob", "on_invoke"),
            ("run_elf_mapping_sim", "on_elf"),
        ]:
            bpf.attach_uprobe(name=args.binary, sym=sym, fn_name=fn)
    mmap_fn = bpf.get_syscall_fnname("mmap")
    bpf.attach_kprobe(event=mmap_fn, fn_name="on_mmap_enter")
    bpf.attach_kretprobe(event=mmap_fn, fn_name="on_mmap_return")
    bpf.attach_kprobe(event=bpf.get_syscall_fnname("mprotect"), fn_name="on_mprotect")
    bpf.attach_kprobe(event=bpf.get_syscall_fnname("munmap"), fn_name="on_munmap")
    bpf.attach_kprobe(event=bpf.get_syscall_fnname("openat"), fn_name="on_openat")
    bpf.attach_kprobe(event=bpf.get_syscall_fnname("read"), fn_name="on_read")
    bpf.attach_kprobe(event=bpf.get_syscall_fnname("execve"), fn_name="on_execve")

    proc = None
    if args.command:
        proc = subprocess.Popen(args.command)
    started = time.time()
    sink = EventSink(
        bpf=bpf,
        started=started,
        output_path=args.output,
        target_pid=proc.pid if proc else None,
        all_pids=args.all_pids,
    )
    bpf["events"].open_perf_buffer(sink)

    try:
        while proc is None or proc.poll() is None:
            bpf.perf_buffer_poll(timeout=100)
        for _ in range(5):
            bpf.perf_buffer_poll(timeout=100)
    except KeyboardInterrupt:
        if proc and proc.poll() is None:
            proc.terminate()
    finally:
        sink.close()
    return proc.returncode if proc else 0


if __name__ == "__main__":
    raise SystemExit(main())
