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
