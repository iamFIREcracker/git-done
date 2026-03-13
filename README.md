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

Commits are filtered by author (from `GIT_DONE_AUTHOR` env var or `git config user.name`) and merge commits are excluded.

## Output

Each commit is rendered as a Markdown section with:

- Commit subject as a `###` heading
- Author date and full hash
- Commit body (if present)
- Full diff in a fenced code block

## git-done-daily

A companion script that runs `git-done` for each day in a date range, writing one `YYYY-MM-DD-reponame.md` file per day (skipping days with no commits).

### Usage

```
git-done-daily [options] [-- git-done-args...]
```

#### Options

| Option | Description |
|---|---|
| `--since YYYY-MM-DD` | Start date |
| `--until YYYY-MM-DD` | End date |
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
