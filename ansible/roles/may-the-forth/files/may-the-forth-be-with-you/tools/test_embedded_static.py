#!/usr/bin/env python3
import os
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
C_RUNNER = BUILD / "standalone_launcher"
FIXED_RUNNER = BUILD / "standalone_launcher_fixed"
AUDIT_RUNNER = BUILD / "standalone_launcher_audit"
PY_RUNNER = ROOT / "harness" / "py_harness.py"


def run(command: list[str], expected: int = 0, env: dict[str, str] | None = None) -> str:
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, env=env, check=False)
    if result.returncode != expected:
        raise RuntimeError(f"expected status {expected}, got {result.returncode}: {result.stdout}")
    return result.stdout


def corrupt_and_reject(data: bytes, mutate) -> None:
    damaged = bytearray(data)
    mutate(damaged)
    with tempfile.NamedTemporaryFile() as target:
        target.write(damaged)
        target.flush()
        run([str(C_RUNNER), "--embedded", target.name], expected=111)


def main() -> int:
    environment = dict(os.environ, FORTH_MARKER="embedded-environment-marker")
    go_bundle = BUILD / "go_static.bundle"
    out = run([str(C_RUNNER), "--embedded", str(go_bundle), "embedded-argument-marker"],
              env=environment)
    assert "embedded static Go ready\nembedded-argument-marker\nembedded-environment-marker\n" in out
    out = run(["python3", str(PY_RUNNER), "--embedded", str(go_bundle),
               "embedded-argument-marker"], env=environment)
    assert "embedded static Go ready\nembedded-argument-marker\nembedded-environment-marker\n" in out
    pie_bundle = BUILD / "hello_static_pie.bundle"
    assert "hello from static demo elf" in run([str(C_RUNNER), "--embedded-raw", str(pie_bundle)])
    assert "hello from static demo elf" in run(
        ["python3", str(PY_RUNNER), "--embedded", str(pie_bundle), "--embedded-raw"])
    assert "hello from static demo elf" in run(
        [str(C_RUNNER), "--embedded-raw", str(BUILD / "hello_static.bundle")])
    assert "forth-loader: rejected" in run(
        [str(FIXED_RUNNER), "--embedded-raw", str(BUILD / "hello_static.bundle")], expected=111)
    for _ in range(3):
        assert "embedded static Go ready" in run([str(C_RUNNER), "--embedded-raw", str(go_bundle)])
        assert "embedded static Go ready" in run(
            ["python3", str(PY_RUNNER), "--embedded", str(go_bundle), "--embedded-raw"])

    bundle = go_bundle.read_bytes()
    marker = struct.pack("<QQ", 0x314C444E42485446, 1)
    manifest = bundle.find(marker)
    assert manifest >= 0
    corrupt_and_reject(bundle, lambda data: struct.pack_into("<Q", data, manifest + 8, 2))
    corrupt_and_reject(bundle, lambda data: struct.pack_into("<Q", data, manifest + 24, 1))
    corrupt_and_reject(bundle, lambda data: struct.pack_into("<Q", data, manifest + 32, 0))
    corrupt_and_reject(bundle, lambda data: struct.pack_into("<Q", data, manifest + 56, 1))
    corrupt_and_reject(bundle[:-1], lambda _data: None)

    template = bytearray((BUILD / "standalone_loader.template.bin").read_bytes())
    dynamic = (BUILD / "hello_dynamic").read_bytes()
    dynamic_manifest = template.find(marker)
    struct.pack_into("<10Q", template, dynamic_manifest, 0x314C444E42485446, 1,
                     len(template) + len(dynamic), len(template), len(dynamic), 1, 1, 0, 0, 0)
    corrupt_and_reject(template + dynamic, lambda _data: None)

    if shutil.which("strace"):
        trace = run(["strace", "-qq", "-f", "-e",
                     "trace=execve,memfd_create,openat,mmap,mprotect",
                     str(AUDIT_RUNNER), "--embedded-raw", str(go_bundle)])
        if ("memfd_create(" in trace or trace.count("execve(") != 1 or
                "PROT_WRITE|PROT_EXEC" in trace):
            raise RuntimeError(f"forbidden loader syscall observed:\n{trace}")
        blocked = run(["strace", "-qq", "-f", "-e", "trace=execve,memfd_create,openat",
                       "-e", "inject=openat:error=EPERM:when=2+",
                       "-e", "inject=memfd_create:error=EPERM",
                       "-e", "inject=execve:error=EPERM:when=2+",
                       str(AUDIT_RUNNER), "--embedded-raw", str(go_bundle)])
        assert "embedded static Go ready" in blocked
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
