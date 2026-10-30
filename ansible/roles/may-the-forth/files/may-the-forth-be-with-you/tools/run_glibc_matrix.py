#!/usr/bin/env python3
import argparse
import os
import pathlib
import shutil
import subprocess
import urllib.request

BASELINES = {
    "2.17": ("ol7", "lib64", "/lib64/ld-linux-x86-64.so.2", "usr/lib64"),
    "2.28": ("ol8", "usr/lib64", "/lib64/ld-linux-x86-64.so.2", "usr/lib64"),
    "2.34": ("ol9", "usr/lib64", "/lib64/ld-linux-x86-64.so.2", "usr/lib64"),
    "2.31": ("focal", "lib/x86_64-linux-gnu", "/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2", "usr/lib/x86_64-linux-gnu"),
    "2.35": ("jammy", "lib/x86_64-linux-gnu", "/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2", "usr/lib/x86_64-linux-gnu"),
    "2.36": ("bookworm", "lib/x86_64-linux-gnu", "/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2", "usr/lib/x86_64-linux-gnu"),
}
PACKAGES = {
    "ol7": ["https://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/glibc-2.17-326.0.9.el7_9.3.x86_64.rpm",
            "https://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/glibc-devel-2.17-326.0.9.el7_9.x86_64.rpm"],
    "ol8": ["https://yum.oracle.com/repo/OracleLinux/OL8/baseos/latest/x86_64/getPackage/glibc-2.28-251.0.5.el8_10.40.x86_64.rpm",
            "https://yum.oracle.com/repo/OracleLinux/OL8/baseos/latest/x86_64/getPackage/glibc-devel-2.28-251.0.5.el8_10.40.x86_64.rpm"],
    "ol9": ["https://yum.oracle.com/repo/OracleLinux/OL9/baseos/latest/x86_64/getPackage/glibc-2.34-275.0.1.el9_8.x86_64.rpm"],
    "focal": ["https://archive.ubuntu.com/ubuntu/pool/main/g/glibc/libc6_2.31-0ubuntu9.18_amd64.deb",
              "https://archive.ubuntu.com/ubuntu/pool/main/g/glibc/libc6-dev_2.31-0ubuntu9.18_amd64.deb"],
    "jammy": ["https://archive.ubuntu.com/ubuntu/pool/main/g/glibc/libc6_2.35-0ubuntu3.15_amd64.deb",
              "https://archive.ubuntu.com/ubuntu/pool/main/g/glibc/libc6-dev_2.35-0ubuntu3.15_amd64.deb"],
    "bookworm": ["https://deb.debian.org/debian/pool/main/g/glibc/libc6_2.36-9+deb12u14_amd64.deb"],
}

def run(command, **kw):
    return subprocess.run(command, check=True, text=True, **kw)

def first(root, patterns):
    for pattern in patterns:
        matches = list(root.glob(pattern))
        if matches:
            return matches[0]
    raise FileNotFoundError(f"missing {'/'.join(patterns)} under {root}")

def fetch(root, versions):
    root.mkdir(parents=True, exist_ok=True)
    for version in versions:
        name = BASELINES[version][0]
        target = root / name
        target.mkdir(parents=True, exist_ok=True)
        for url in PACKAGES[name]:
            package = root / pathlib.PurePosixPath(url).name
            if not package.exists():
                urllib.request.urlretrieve(url, package)
            if package.suffix == ".deb":
                run(["dpkg-deb", "-x", str(package), str(target)])
            else:
                run(["7z", "x", "-y", str(package), "-o" + str(target)], stdout=subprocess.DEVNULL)
                payload = next(target.glob(package.stem + ".cpio*"))
                if payload.suffix == ".zstd":
                    unpacked = payload.with_suffix("")
                    run(["unzstd", "-f", str(payload), "-o", str(unpacked)])
                    payload = unpacked
                with payload.open("rb") as source:
                    subprocess.run(["cpio", "-idm", "--quiet"], cwd=target, stdin=source, check=True)
        if name.startswith("ol"):
            (target / "lib").mkdir(exist_ok=True)
            link = target / "lib/x86_64-linux-gnu"
            if not link.exists(): link.symlink_to("../lib64")
            lib64 = target / "lib64"
            if not lib64.exists(): lib64.symlink_to("usr/lib64")

def build_one(repo, output, root, librel, interpreter, crtrel):
    output.mkdir(parents=True, exist_ok=True)
    depobj, dep = output / "dependency.o", output / "libglibc_matrix_dependency.so"
    mainobj, program = output / "program.o", output / "program"
    run(["cc", "-O2", "-fpic", "-ftls-model=initial-exec", "-c",
         str(repo / "examples/glibc_matrix_dependency.c"), "-o", str(depobj)])
    run(["cc", "-nostdlib", "-shared", "-o", str(dep), str(depobj),
         "-Wl,-soname,libglibc_matrix_dependency.so", "-Wl,--version-script," + str(repo / "examples/glibc_matrix.map")])
    run(["cc", "-O2", "-fpie", "-c", str(repo / "examples/glibc_matrix_program.c"), "-o", str(mainobj)])
    libdir = root / librel
    libc = first(libdir, ["libc.so.6", "libc-*.so"])
    loader = root / interpreter.lstrip("/")
    local_libc = output / "libc.so.6"
    local_loader = output / "ld-linux-x86-64.so.2"
    shutil.copy2(libc, local_libc)
    shutil.copy2(loader, local_loader)
    crt = root / crtrel
    if not (crt / "Scrt1.o").exists():
        crt = pathlib.Path("/usr/lib/x86_64-linux-gnu")
    libgcc = run(["cc", "-print-file-name=libgcc.a"], capture_output=True).stdout.strip()
    run(["cc", "-nostdlib", "-pie", "-o", str(program), str(crt / "Scrt1.o"),
         str(crt / "crti.o"), str(mainobj), str(dep), str(libc),
         str(crt / "libc_nonshared.a"), libgcc, str(crt / "crtn.o"),
         "-Wl,--allow-shlib-undefined", "-Wl,--dynamic-linker," + str(local_loader), "-Wl,-rpath,$ORIGIN"])
    return program

def verify(harness, program, root, launcher=None, blob=None):
    for path in (program, program.with_name("program-stripped")):
        if path != program:
            shutil.copy2(program, path)
            run(["strip", "--strip-all", str(path)])
        result = run([str(harness), "--elf-forth", str(path), "--seed", "1", "--rounds", "2",
                      "--forth-self-transfer",
                      "--forth-arg", "matrix-argument", "--forth-env", "FORTH_MATRIX_ENV=matrix-environment"],
                     capture_output=True)
        for marker in ("matrix-argument", "matrix-environment", "matrix-dependency-ok", "glibc-matrix-ok"):
            if marker not in result.stdout:
                raise RuntimeError(f"{path}: missing {marker}")
        if '"kind":"program"' not in result.stdout or '"rounds_done":2' not in result.stdout:
            raise RuntimeError(f"{path}: did not enter transformed original entry")
        if launcher:
            env = dict(os.environ, FORTH_MATRIX_ENV="matrix-environment")
            result = run([str(launcher), str(blob), str(path), "matrix-argument"],
                         capture_output=True, env=env)
            for marker in ("matrix-argument", "matrix-environment", "matrix-dependency-ok", "glibc-matrix-ok"):
                if marker not in result.stdout:
                    raise RuntimeError(f"{path}: standalone missing {marker}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--harness", default="build/c_harness")
    parser.add_argument("--matrix-root", default="/tmp/glibc-matrix")
    parser.add_argument("--baseline", action="append", choices=BASELINES)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--launcher")
    parser.add_argument("--blob")
    args = parser.parse_args()
    repo = pathlib.Path(__file__).resolve().parents[1]
    build = repo / "build/glibc-matrix"
    versions = args.baseline or list(BASELINES)
    if args.fetch: fetch(pathlib.Path(args.matrix_root), versions)
    for version in versions:
        name, librel, interpreter, crtrel = BASELINES[version]
        root = pathlib.Path(args.matrix_root) / name
        program = build_one(repo, build / version, root, librel, interpreter, crtrel)
        verify(repo / args.harness, program, root,
               repo / args.launcher if args.launcher else None,
               repo / args.blob if args.blob else None)
        print(f"glibc_matrix={{\"version\":\"{version}\",\"ok\":true}}")

if __name__ == "__main__":
    main()
