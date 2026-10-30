# Polymorphic Execution

This repo is best understood as a Forth VM with polymorphic execution. Polymorphism is not a separate engine bolted beside the VM; it is part of the VM execution pipeline.

The VM compiles input Forth text into an original token stream, applies seeded transform rounds to produce a semantically equivalent transformed token stream, validates that transformed stream, and then executes it. When loader-like behavior is written in Forth, that loader vocabulary is transformed and validated before it runs.

## Transform Rounds

`--rounds N` requests multiple rounds. The VM clamps the value to `1..4`.

Each round reads one token buffer and writes another. The implementation alternates between the transformed buffer and a scratch buffer so later rounds can rewrite the prior round without overwriting it.

Validation runs after each round. If a later round fails validation, execution falls back to the last valid token stream.

Control-flow tokens such as `for i ... next` and `if ... else ... then` are branch-aware in the transform path. After each round, the VM scans the transformed stream and repairs relative offsets to account for inserted or expanded tokens. That lets loop-heavy and branch-heavy Forth loader code execute from the transformed stream instead of falling back to the original stream. The current loop model is intentionally simple: one active counted loop at a time, with sequential loops supported.

## Transform Families

Current transform families include:

- stack-neutral insertion, such as `0 drop`,
- literal splitting, such as `n -> a b +`,
- neutral literal forms, such as `n 0 +` and `n 1 *`,
- zero literal forms, such as `k k -`,
- literal increment/decrement forms,
- even literal doubling with `2*`,
- invert pairs,
- subtraction rewrite with `negate +`,
- equality rewrite with subtraction plus zero comparison,
- boolean normalization,
- stack-equivalent operator rewrites,
- depth-aware no-ops, such as `dup drop`, `swap swap`, and `over drop`,
- post-op neutral work, such as `0 +`, `1 *`, `invert invert`, and `1+ 1-`.

## Stack Safety

The transformer maintains a simulated stack depth while it rewrites. Context-sensitive transforms are only selected when their stack effects are safe for the current depth.

After a round completes, the VM validates the whole transformed stream. The validator checks that every token has enough stack input and that the stack does not exceed the fixed workspace stack size.

## Trace Records

`--dump-tokens` prints original tokens, final transformed tokens, and trace records. Trace storage is bounded, so high-round runs may have more transform events than retained trace entries.

The transform count is cumulative across rounds. The transformed token count is the size of the final token stream.

## Detection Relevance

The polymorphic execution metadata is useful for lab introspection, but the detection rules do not rely on it. The detection side focuses on behavior: executable anonymous memory, file I/O, process execution, and loader-like activity.
