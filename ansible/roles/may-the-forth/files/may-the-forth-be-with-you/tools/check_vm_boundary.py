#!/usr/bin/env python3
"""Fail when ELF format knowledge leaks into the assembly VM."""

import pathlib
import re
import sys


vm = pathlib.Path("src/forth_vm.asm")
text = vm.read_text()
code = "\n".join(line.split(";", 1)[0] for line in text.splitlines())

forbidden = {
    "ELF-named identifiers": r"(?i)\b(?:elf64|pt_load|pt_dynamic|dt_[a-z0-9_]+|r_x86_64_[a-z0-9_]+)\b",
    "ELF opcode families": r"\bOP_(?:E_|PH_)",
    "ELF field words": r"(?i)(?:e\.(?:magic|class|data|type|machine|entry|phoff|phentsz|phnum)|ph\.(?:type|flags|offset|vaddr|filesz|memsz|align))",
    "ELF program-header parser": r"\bread_ph_field\b",
}

failed = False
for description, pattern in forbidden.items():
    if match := re.search(pattern, code):
        line = code.count("\n", 0, match.start()) + 1
        print(f"{vm}:{line}: prohibited {description}: {match.group(0)}", file=sys.stderr)
        failed = True

raise SystemExit(failed)
