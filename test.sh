#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_DONE="$SCRIPT_DIR/git-done"

PASS=0
FAIL=0
TMPDIR=""

setup_repo() {
  TMPDIR="$(mktemp -d)"
  cd "$TMPDIR"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
}

cleanup() {
  if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
  fi
}
trap cleanup EXIT

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL [$label]: expected output to contain:"
    echo "  $needle"
  fi
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    FAIL=$((FAIL + 1))
    echo "FAIL [$label]: expected output NOT to contain:"
    echo "  $needle"
  else
    PASS=$((PASS + 1))
  fi
}

assert_match() {
  local label="$1" haystack="$2" pattern="$3"
  if printf '%s' "$haystack" | grep -qE "$pattern"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL [$label]: expected output to match pattern:"
    echo "  $pattern"
  fi
}

run_git_done() {
  GIT_DONE_AUTHOR="Test User" "$GIT_DONE" "$@"
}

# ── Test 1: Basic formatting ───────────────────────────────────────

test_basic_formatting() {
  echo "-- test_basic_formatting"
  setup_repo

  echo "hello" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Add greeting file" -m "This is the body of the commit."

  local hash
  hash="$(git rev-parse HEAD)"
  local output
  output="$(run_git_done -1)"

  assert_contains "heading" "$output" "### Add greeting file"
  assert_contains "date bold" "$output" "**2025-01-15 10:00:00 +0000**"
  assert_contains "hash inline code" "$output" "\`$hash\`"
  assert_contains "body" "$output" "This is the body of the commit."
  assert_match   "diff fence" "$output" '```diff'
  assert_contains "patch content" "$output" "+hello"
}

# ── Test 2: Commit with no body ────────────────────────────────────

test_no_body() {
  echo "-- test_no_body"
  setup_repo

  echo "data" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "No body commit"

  local output
  output="$(run_git_done -1)"

  assert_contains     "heading present" "$output" "### No body commit"
  assert_match        "diff fence" "$output" '```diff'
  # Body section would be a blank line followed by text between metadata and fence.
  # With no body the metadata line is immediately followed by the fence block.
  assert_not_contains "no stray body" "$output" "This is the body"
}

# ── Test 3: Backticks in patch ─────────────────────────────────────

test_backticks_in_patch() {
  echo "-- test_backticks_in_patch"
  setup_repo

  # Create a file whose contents include triple backticks
  printf '```\ncode\n```\n' > fenced.md
  git add fenced.md
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Add fenced markdown"

  local output
  output="$(run_git_done -1)"

  # The patch contains ``` so the outer fence must use at least ```` (4 backticks)
  assert_match   "outer fence longer" "$output" '````'
  assert_contains "heading" "$output" "### Add fenced markdown"
}

# ── Test 4: Backticks in commit body ──────────────────────────────

test_backticks_in_body() {
  echo "-- test_backticks_in_body"
  setup_repo

  echo "x" > file.txt
  git add file.txt
  local body
  body="$(printf 'Here is some code:\n\n```\nfoo\n```')"
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Commit with backtick body" -m "$body"

  local output
  output="$(run_git_done -1)"

  # Backticks in body don't affect heading level — heading should still be ###
  assert_contains "heading level" "$output" "### Commit with backtick body"
  assert_contains "body preserved" "$output" 'Here is some code:'
}

# ── Test 5: Headings in commit body ───────────────────────────────

test_headings_in_body() {
  echo "-- test_headings_in_body"
  setup_repo

  echo "y" > file.txt
  git add file.txt
  local body
  body="$(printf '### Sub-heading in body\nSome text.')"
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Commit with heading body" -m "$body"

  local output
  output="$(run_git_done -1)"

  # Body contains "###" so the outer heading must use at least #### (4 #'s)
  assert_match        "heading elevated" "$output" '####[^#]'
  assert_contains     "body present" "$output" "### Sub-heading in body"
}

# ── Test 6: Both backticks and headings ───────────────────────────

test_both_escapes() {
  echo "-- test_both_escapes"
  setup_repo

  # File with backtick fences so patch triggers fence escaping
  printf '```\ncode\n```\n' > fenced.md
  git add fenced.md
  # Body with heading markers so heading escaping is triggered too
  local body
  body="$(printf '### Note\nDetails here.')"
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Both escapes" -m "$body"

  local output
  output="$(run_git_done -1)"

  # Heading must be elevated (body has ###)
  assert_match   "heading elevated" "$output" '####[^#]'
  # Fence must be wider (patch has ```)
  assert_match   "fence widened" "$output" '````'
  assert_contains "body present" "$output" "### Note"
}

# ── Run all tests ─────────────────────────────────────────────────

test_basic_formatting
test_no_body
test_backticks_in_patch
test_backticks_in_body
test_headings_in_body
test_both_escapes

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
