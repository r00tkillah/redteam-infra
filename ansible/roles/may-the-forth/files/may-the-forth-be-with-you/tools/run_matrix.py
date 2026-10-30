#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys


def run_one(harness: str, script: str, seed: int, rounds: int) -> dict:
    proc = subprocess.run(
        [harness, "--script", script, "--seed", str(seed), "--rounds", str(rounds)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    output = ""
    meta = {}
    in_output = False
    for line in proc.stdout.splitlines():
        if line.startswith("forth_output="):
            output = line.removeprefix("forth_output=")
            in_output = True
        elif line.startswith("forth_meta="):
            meta = json.loads(line.removeprefix("forth_meta="))
            in_output = False
        elif in_output:
            output += "\n" + line
    return {
        "seed": seed,
        "returncode": proc.returncode,
        "output": output,
        "meta": meta,
        "stderr": proc.stderr,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--harness", default="build/c_harness")
    parser.add_argument("--script", default="examples/math.fs")
    parser.add_argument("--seeds", default="1,2,3,4,5")
    parser.add_argument("--rounds", type=lambda s: int(s, 0), default=1)
    args = parser.parse_args()

    seeds = [int(s, 0) for s in args.seeds.split(",") if s]
    rows = [run_one(args.harness, args.script, seed, args.rounds) for seed in seeds]
    baseline = rows[0]["output"] if rows else ""
    ok = True
    for row in rows:
        row["equivalent_to_baseline"] = row["output"] == baseline
        meta = row.get("meta", {})
        trace_count = meta.get("trace_count", 0)
        transforms = meta.get("transforms", 0)
        row["trace_matches_transforms"] = trace_count == transforms
        row["trace_captured_or_saturated"] = 0 <= trace_count <= transforms
        row["token_growth"] = meta.get("transformed_tokens", 0) >= meta.get("original_tokens", 0)
        row["transform_validated"] = meta.get("validate_status") == 1
        row["rounds_completed"] = meta.get("rounds_done") == meta.get("rounds")
        ok = (
            ok
            and row["returncode"] == 0
            and row["equivalent_to_baseline"]
            and row["trace_captured_or_saturated"]
            and row["token_growth"]
            and row["transform_validated"]
            and row["rounds_completed"]
        )
        print(json.dumps(row, sort_keys=True))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
