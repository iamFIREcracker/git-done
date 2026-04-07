# git-done

A `git log` wrapper that outputs formatted Markdown — useful for generating changelogs, standup notes, or "what I did" reports.

## Requirements

- [Roswell](https://github.com/roswell/roswell) (Common Lisp scripting environment)

## Usage

```
git-done [git-log-args...]
```

All arguments are passed through to `git log`, so you can use things like:

```
git-done --since="2 days ago"
git-done -5
git-done --since=2025-01-01 --until=2025-02-01
```

Commits are filtered by author (from `GIT_DONE_AUTHOR` env var or `git config user.name`) and merge commits are excluded. All branches are included (`--all`), so you get everything you've done regardless of which branch it's on.

When `--since`/`--until` are used, commits are bucketed by **committer date**. This means amended commits appear on the day they were amended (not the original author date), accurately reflecting when work landed. Rebased duplicates are removed via `git patch-id`, keeping only the earliest occurrence of each logical change.

To support dedup across rebases, a lookback window extends the query range (default 90 days before `--since`). Set `GIT_DONE_LOOKBACK_DAYS` to adjust this (e.g. `GIT_DONE_LOOKBACK_DAYS=180`).

## Output

Each commit is rendered as a Markdown section with:

- Commit subject as a `###` heading
- Author date (when the work was written) and full hash
- Commit body (if present)
- Full diff in a fenced code block

## Excluding files from diffs

Some files (binaries, generated data, lock files) produce noisy diffs. You can suppress their patch output using git's built-in `-diff` attribute in `.gitattributes` or `.git/info/attributes`:

```gitattributes
package-lock.json -diff
*.pdf -diff
data/*.csv -diff
```

Files marked `-diff` will show a short `Binary files differ` line instead of a full patch. This applies to all git diff operations, not just `git-done`.

## git-done-daily

A companion script that runs `git-done` for each day in a date range, writing one `YYYY-MM-DD-reponame.md` file per day (skipping days with no commits).

### Usage

```
git-done-daily [options] [-- git-done-args...]
```

#### Options

| Option | Description |
|---|---|
| `--since DATE` | Start date (`YYYY`, `YYYY-MM`, or `YYYY-MM-DD`) |
| `--until DATE` | End date (same formats; defaults to today) |
| `--today` | Today only |
| `--yesterday` | Yesterday only |
| `--week` | Current week (Mon–Sun) |
| `--month [YYYY-MM]` | Month (default: current) |
| `--year [YYYY]` | Year (default: current) |
| `--name NAME` | Override repo name in filenames |
| `-C DIR` | Run in directory DIR |

Everything after `--` is passed through to `git-done`.

### Examples

```
# Generate daily files for the current week
git-done-daily --week

# Run against a different repo, output files land in your cwd
git-done-daily --month 2026-02 -C ~/Workspace/other-repo

# Full year with a custom name
git-done-daily --year 2025 --name my-project -C ~/Workspace/my-project
```
