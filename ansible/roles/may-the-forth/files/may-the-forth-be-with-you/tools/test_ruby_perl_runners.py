#!/usr/bin/env python3
import os
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
RUBY = ROOT / "harness" / "ruby_harness.rb"
PERL = ROOT / "harness" / "perl_harness.pl"
SIGNAL_PREFIX = (b"\xf3\x0f\x1e\xfa\x31\xff\xe9\x09\x00\x00\x00"
                 b"\xb8\x0f\x00\x00\x00\x0f\x05\x0f\x0b")


def run(command: list[str], expected: int = 0, env: dict[str, str] | None = None) -> str:
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=False, env=env)
    if result.returncode != expected:
        raise RuntimeError(f"expected {expected}, got {result.returncode}: {result.stdout}")
    return result.stdout


def run_failure(command: list[str]) -> str:
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=False)
    if result.returncode == 0:
        raise RuntimeError(f"expected failure: {result.stdout}")
    return result.stdout


def main() -> int:
    go_bundle = BUILD / "go_static.bundle"
    signal_go = BUILD / "go_static.signal.bundle"
    pie_bundle = BUILD / "hello_static_pie.bundle"
    signal_pie = BUILD / "hello_static_pie.signal.bundle"
    assert signal_go.read_bytes()[len(SIGNAL_PREFIX):] == go_bundle.read_bytes()
    assert signal_pie.read_bytes()[len(SIGNAL_PREFIX):] == pie_bundle.read_bytes()
    for _ in range(4):
        assert "embedded static Go ready" in run(["ruby", str(RUBY), "--embedded-raw", str(go_bundle)])
        assert "embedded static Go ready" in run(["perl", str(PERL), "--embedded-signal", str(signal_go)])
    assert "hello from static demo elf" in run(["ruby", str(RUBY), "--embedded-raw", str(pie_bundle)])
    assert "hello from static demo elf" in run(["perl", str(PERL), "--embedded-signal", str(signal_pie)])

    bundle = bytearray(go_bundle.read_bytes())
    marker = bundle.find(struct.pack("<QQ", 0x314C444E42485446, 1))
    assert marker >= 0
    struct.pack_into("<Q", bundle, marker + 8, 2)
    with tempfile.NamedTemporaryFile() as malformed, tempfile.NamedTemporaryFile() as signal_malformed:
        malformed.write(bundle)
        malformed.flush()
        signal_malformed.write(SIGNAL_PREFIX + bundle)
        signal_malformed.flush()
        assert "forth-loader: rejected" in run(
            ["ruby", str(RUBY), "--embedded-raw", malformed.name], expected=111)
        assert "forth-loader: rejected" in run(
            ["perl", str(PERL), "--embedded-signal", signal_malformed.name], expected=111)
    with tempfile.NamedTemporaryFile() as truncated:
        truncated.write(SIGNAL_PREFIX + go_bundle.read_bytes()[:4096])
        truncated.flush()
        run_failure(["perl", str(PERL), "--embedded-signal", truncated.name])

    no_fiddle = run_failure(["ruby", "-I", str(ROOT / "tests" / "no_fiddle"), str(RUBY),
                             "--embedded-raw", str(go_bundle)])
    assert "without standard-library Fiddle" in no_fiddle
    run(["perl", "-c", str(PERL)], env=dict(os.environ, PERL5LIB="", PERL_LOCAL_LIB_ROOT=""))

    if shutil.which("strace"):
        ruby_trace = run(["strace", "-qq", "-f", "-e",
                          "trace=execve,memfd_create,mmap,mprotect",
                          "ruby", str(RUBY), "--embedded-raw", str(go_bundle)])
        if ("embedded static Go ready" not in ruby_trace or
                "PROT_WRITE|PROT_EXEC" in ruby_trace or "memfd_create(" in ruby_trace or
                ruby_trace.count("execve(") != 1):
            raise RuntimeError(f"forbidden Ruby runner behavior:\n{ruby_trace}")
        trace = run(["strace", "-qq", "-f", "-e",
                     "trace=execve,memfd_create,mmap,mprotect,rt_sigaction,tgkill",
                     "-e", "signal=SIGUSR2", "perl", str(PERL), "--embedded-signal", str(signal_go)])
        required = ("mprotect(", "rt_sigaction(SIGUSR2", "tgkill(", "embedded static Go ready")
        if any(item not in trace for item in required) or trace.count("--- SIGUSR2") != 1:
            raise RuntimeError(f"missing signal-entry event:\n{trace}")
        if "PROT_WRITE|PROT_EXEC" in trace or "memfd_create(" in trace or trace.count("execve(") != 1:
            raise RuntimeError(f"forbidden runner behavior:\n{trace}")
        failed = subprocess.run(
            ["strace", "-qq", "-e", "inject=rt_sigaction:error=EPERM:when=3", "perl", str(PERL),
             "--embedded-signal", str(signal_go)], cwd=ROOT, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, check=False)
        if failed.returncode == 0 or "perl_harness: rt_sigaction" not in failed.stdout:
            raise RuntimeError(f"rt_sigaction failure was not reported:\n{failed.stdout}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
