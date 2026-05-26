# Performance TODOs

- [ ] Avoid redundant `git log --all` traversal: `commit-refs` and `batch-patch-ids` both do a full `git log --all` over the same range. Combine into a single traversal by piping the first `git log` (with `-p`) directly into `git patch-id`.

- [ ] Batch `format-commit` calls: currently spawns 4 git processes per commit (subject, date, body, patch). Replace with a single `git log` using a custom `--pretty` format with a unique record separator (`%x00`) for all hashes at once. Use `git diff-tree --stdin` or similar for patches.

- [ ] Reduce default lookback window for dedup: with `--year`, the 90-day lookback makes the total window ~15 months. Consider whether a shorter default (e.g. 30 days) would catch most rebases without the extra cost.

- [ ] Stream `batch-patch-ids` output instead of capturing as a single string: use `:output :stream` and read line-by-line to reduce memory pressure on large ranges.
