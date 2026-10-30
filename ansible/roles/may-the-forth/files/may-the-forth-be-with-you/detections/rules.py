#!/usr/bin/env python3
import argparse
import json
import sys
from collections import defaultdict


def load_events(path: str) -> list[dict]:
    events = []
    with (open(path, "r", encoding="utf-8") if path != "-" else sys.stdin) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            events.append(json.loads(line))
    return events


def correlate(events: list[dict]) -> list[dict]:
    by_pid: dict[int, list[dict]] = defaultdict(list)
    for event in events:
        pid = int(event.get("pid", event.get("tgid", 0)) or 0)
        by_pid[pid].append(event)

    findings = []
    executable_memory_pids = set()
    executable_memory_times = []
    for pid, rows in by_pid.items():
        anonymous_rw_mmaps = [
            row for row in rows
            if row.get("event") == "mmap"
            and "r" in str(row.get("prot", "")).lower()
            and "w" in str(row.get("prot", "")).lower()
            and "x" not in str(row.get("prot", "")).lower()
            and (int(row.get("flags", 0) or 0) & 0x20) != 0
        ]
        anonymous_rx_mmaps = [
            row for row in rows
            if row.get("event") == "mmap"
            and "x" in str(row.get("prot", "")).lower()
            and (int(row.get("flags", 0) or 0) & 0x20) != 0
        ]
        rx_mprotects = [
            row for row in rows
            if row.get("event") == "mprotect"
            and "x" in str(row.get("prot", "")).lower()
        ]

        rw_to_rx = False
        rx_addr = 0
        for mmap_event in anonymous_rw_mmaps:
            mmap_len = int(mmap_event.get("length", 0) or 0)
            mmap_ts = int(mmap_event.get("ts_ns", 0) or 0)
            mmap_addr = int(mmap_event.get("addr", 0) or 0)
            for mprotect_event in rx_mprotects:
                prot_len = int(mprotect_event.get("length", 0) or 0)
                prot_ts = int(mprotect_event.get("ts_ns", 0) or 0)
                prot_addr = int(mprotect_event.get("addr", 0) or 0)
                length_close = mmap_len == 0 or prot_len == 0 or abs(mmap_len - prot_len) <= 4096
                temporal = mmap_ts == 0 or prot_ts == 0 or prot_ts >= mmap_ts
                address_close = (
                    mmap_addr == 0
                    or prot_addr == 0
                    or mmap_addr == prot_addr
                    or (mmap_addr <= prot_addr < mmap_addr + max(mmap_len, 1))
                )
                if length_close and temporal and address_close:
                    rw_to_rx = True
                    rx_addr = prot_addr or mmap_addr
                    break
            if rw_to_rx:
                break

        executable_anonymous_memory = bool(anonymous_rx_mmaps) or rw_to_rx
        score = sum([
            bool(anonymous_rw_mmaps),
            bool(rx_mprotects),
            rw_to_rx,
            bool(anonymous_rx_mmaps),
        ])

        if executable_anonymous_memory and score >= 2:
            executable_memory_pids.add(pid)
            event_times = [
                int(row.get("ts_ns", 0) or 0)
                for row in anonymous_rw_mmaps + anonymous_rx_mmaps + rx_mprotects
                if int(row.get("ts_ns", 0) or 0) > 0
            ]
            if event_times:
                executable_memory_times.append((pid, min(event_times), max(event_times)))
            findings.append({
                "pid": pid,
                "score": score,
                "detection": "anonymous_memory_made_executable",
                "signals": {
                    "anonymous_rw_mapping": bool(anonymous_rw_mmaps),
                    "rx_mprotect": bool(rx_mprotects),
                    "rw_to_rx_transition": rw_to_rx,
                    "anonymous_rx_mapping": bool(anonymous_rx_mmaps),
                },
            })

            has_file_io = any(row.get("event") in {"openat", "read"} for row in rows)
            if has_file_io:
                findings.append({
                    "pid": pid,
                    "score": score + 1,
                    "detection": "executable_anonymous_memory_with_file_io",
                    "signals": {
                        "anonymous_executable_memory": True,
                        "openat": any(row.get("event") == "openat" for row in rows),
                        "read": any(row.get("event") == "read" for row in rows),
                    },
                })

            munmaps = [row for row in rows if row.get("event") == "munmap"]
            unmapped_after = False
            for row in munmaps:
                unmap_addr = int(row.get("addr", 0) or 0)
                if rx_addr == 0 or unmap_addr == 0 or unmap_addr == rx_addr:
                    unmapped_after = True
                    break
            if unmapped_after:
                findings.append({
                    "pid": pid,
                    "score": score + 1,
                    "detection": "executable_anonymous_memory_lifecycle",
                    "signals": {
                        "anonymous_executable_memory": True,
                        "munmap": True,
                        "rx_addr": rx_addr,
                    },
                })

            interpreter_opens = [
                row for row in rows
                if row.get("event") == "openat"
                and "ld-linux" in str(row.get("path", ""))
            ]
            if len(interpreter_opens) >= 2:
                findings.append({
                    "pid": pid,
                    "score": score + len(interpreter_opens),
                    "detection": "repeated_dynamic_linker_activity_near_executable_memory",
                    "signals": {
                        "anonymous_executable_memory": True,
                        "ld_linux_open_count": len(interpreter_opens),
                    },
                })

    exec_events = [row for row in events if row.get("event") == "execve"]
    for exec_event in exec_events:
        exec_ts = int(exec_event.get("ts_ns", 0) or 0)
        for source_pid, first_ts, last_ts in executable_memory_times:
            temporal = exec_ts == 0 or last_ts == 0 or 0 <= exec_ts - last_ts <= 5_000_000_000
            if temporal:
                findings.append({
                    "pid": int(exec_event.get("pid", 0) or 0),
                    "source_pid": source_pid,
                    "score": 3,
                    "detection": "process_exec_near_executable_anonymous_memory",
                    "signals": {
                        "anonymous_executable_memory_pid": source_pid,
                        "execve": True,
                        "path": exec_event.get("path", ""),
                    },
                })
                break
    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("events", nargs="?", default="-")
    args = parser.parse_args()

    findings = correlate(load_events(args.events))
    for finding in findings:
        print(json.dumps(finding, sort_keys=True))
    return 0 if findings else 1


if __name__ == "__main__":
    raise SystemExit(main())
