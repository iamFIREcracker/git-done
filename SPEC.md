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

## Arguments

All extra CLI arguments are passed through to `git log` (e.g. `-2`, `--since`, `--until`).

## Output format

Each commit is rendered as a Markdown section:

1. **Heading** — commit subject as a `###` heading
2. **Metadata** — full author date (ISO format) in bold, followed by the full commit hash in inline code
3. **Body** — commit body, if present, rendered as-is (supports Markdown)
4. **Patch** — full diff in a fenced code block with `diff` language tag

Commits are sorted by author date, most recent first.

## Markdown escaping

To avoid breaking Markdown when commit content contains fence or heading markers:

- **Code fences**: if the patch contains backtick runs, the outer fence uses more backticks than the longest consecutive run found (minimum 3)
- **Headings**: if the subject or body contains lines starting with `#`, the heading prefix uses more `#` characters than the longest leading run found (minimum 3)
