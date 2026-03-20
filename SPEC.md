# git-done

A `git log` wrapper that outputs formatted Markdown.

## Implementation

The script is implemented as a [Roswell](https://github.com/roswell/roswell) script (Common Lisp).

## Author filtering

- Filter commits by author using `--author`
- Author is determined by (in order of priority):
  1. `GIT_DONE_AUTHOR` environment variable
  2. `git config user.name`
- Merge commits are excluded (`--no-merges`)
- All branches are included (`--all`)

## Date bucketing

Commits are bucketed by **committer date** (not author date). This means amended commits appear on the day they were amended, not the day they were originally authored. This is the correct behavior because `git commit --amend` preserves the author date but updates the committer date, and we want to track when work actually landed.

## Deduplication

Rebased commits produce multiple git objects with different hashes but identical diffs. To avoid showing the same logical change multiple times, commits are deduplicated by `git patch-id --stable`. When duplicates are found, only the commit with the oldest committer date is kept (i.e., the original, not the rebase).

To support deduplication across rebases, `git-done` fetches commits from a broader lookback window (default 90 days before `--since`). This ensures that original commits are visible for dedup even when querying a narrow date range. The lookback window is configurable via `GIT_DONE_LOOKBACK_DAYS` (environment variable, default 90). Deduplication runs on the full lookback window before filtering to the user's requested range.

## Arguments

All extra CLI arguments are passed through to `git log` (e.g. `-2`, `--since`, `--until`).

## Output format

Each commit is rendered as a Markdown section:

1. **Heading** — commit subject as a `###` heading
2. **Metadata** — author date (ISO format, `%ad`) in bold, followed by the full commit hash in inline code. Note: the displayed date is the *author* date (when the work was originally written), even though bucketing uses the committer date
3. **Body** — commit body, if present, rendered as-is (supports Markdown)
4. **Patch** — full diff in a fenced code block with `diff` language tag

Commits are sorted by committer date, most recent first.

## Markdown escaping

To avoid breaking Markdown when commit content contains fence or heading markers:

- **Code fences**: if the patch contains backtick runs, the outer fence uses more backticks than the longest consecutive run found (minimum 3)
- **Headings**: the commit heading is always `###`. If the body contains lines starting with `#`, those lines are escaped by prepending extra `#` characters so they nest under `###` (i.e., at least `####`)
