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

  # Outer heading stays ### (structure unchanged)
  assert_contains     "heading unchanged" "$output" "### Commit with heading body"
  # Body's ### is escaped to #### (nested under ###)
  assert_contains     "body heading nested" "$output" "#### Sub-heading in body"
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

  # Outer heading stays ### (structure unchanged)
  assert_contains "heading unchanged" "$output" "### Both escapes"
  # Body's ### is escaped to #### (nested under ###)
  assert_contains "body heading nested" "$output" "#### Note"
  # Fence must be wider (patch has ```)
  assert_match   "fence widened" "$output" '````'
}

# ── Test 7: Rebased commit not duplicated ────────────────────────

test_rebase_dedup() {
  echo "-- test_rebase_dedup"
  setup_repo

  # Base commit on main
  echo "base" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-14 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-14 10:00:00 +0000" \
  git commit -q -m "Base commit"

  # Feature branch with a commit authored "yesterday"
  git checkout -q -b feature
  echo "feature work" > feature.txt
  git add feature.txt
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Add feature work"

  # Save the pre-rebase hash (we'll restore a ref to it after rebase)
  local old_hash
  old_hash="$(git rev-parse HEAD)"

  # Meanwhile, main gets a new commit
  git checkout -q main
  echo "main work" > main.txt
  git add main.txt
  GIT_AUTHOR_DATE="2025-01-15 12:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 12:00:00 +0000" \
  git commit -q -m "Main branch work"

  # Rebase feature onto main — committer date becomes "today" (Jan 16)
  git checkout -q feature
  GIT_COMMITTER_DATE="2025-01-16 09:00:00 +0000" \
  git rebase -q main

  # Restore a ref to the old commit (simulates origin/feature before force-push)
  git branch pre-rebase "$old_hash"

  # Now both pre-rebase and feature have "Add feature work" with same patch
  # but different hashes

  # Yesterday (Jan 15): should show the commit (that's when it was authored)
  local output_yesterday
  output_yesterday="$(run_git_done --since=2025-01-15T00:00:00 --until=2025-01-16T00:00:00)"
  assert_contains "rebase: yesterday has commit" "$output_yesterday" "Add feature work"

  # Today (Jan 16): should NOT show "Add feature work" — it's just a rebase,
  # the actual work was done yesterday
  local output_today
  output_today="$(run_git_done --since=2025-01-16T00:00:00 --until=2025-01-17T00:00:00)"
  assert_not_contains "rebase: today should not have rebased commit" "$output_today" "Add feature work"

  # Spanning range (Jan 15–17): should show "Add feature work" exactly once
  # (patch-id dedup keeps only the oldest committer date)
  local output_span
  output_span="$(run_git_done --since=2025-01-15T00:00:00 --until=2025-01-17T00:00:00)"
  local count
  count="$(printf '%s' "$output_span" | grep -cF "Add feature work")"
  if [ "$count" -eq 1 ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL [rebase: spanning range should have commit exactly once]: found $count occurrences, expected 1"
  fi
}

# ── Test 8: Multiple rebases on the same day ─────────────────────

test_rebase_same_day() {
  echo "-- test_rebase_same_day"
  setup_repo

  # Base commit on main
  echo "base" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-14 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-14 10:00:00 +0000" \
  git commit -q -m "Base commit"

  # Feature branch with a commit
  git checkout -q -b feature
  echo "feature work" > feature.txt
  git add feature.txt
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Add feature work"
  local hash1
  hash1="$(git rev-parse HEAD)"

  # First rebase: main gets a new commit, rebase feature onto it
  git checkout -q main
  echo "main work 1" > main1.txt
  git add main1.txt
  GIT_AUTHOR_DATE="2025-01-15 11:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 11:00:00 +0000" \
  git commit -q -m "Main work 1"

  git checkout -q feature
  GIT_COMMITTER_DATE="2025-01-15 14:00:00 +0000" \
  git rebase -q main
  local hash2
  hash2="$(git rev-parse HEAD)"

  # Keep ref to first rebase
  git branch rebase-1 "$hash1"

  # Second rebase: main gets another commit, rebase feature again
  git checkout -q main
  echo "main work 2" > main2.txt
  git add main2.txt
  GIT_AUTHOR_DATE="2025-01-15 15:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 15:00:00 +0000" \
  git commit -q -m "Main work 2"

  git checkout -q feature
  GIT_COMMITTER_DATE="2025-01-15 17:00:00 +0000" \
  git rebase -q main

  # Keep ref to second rebase
  git branch rebase-2 "$hash2"

  # Now 3 copies of "Add feature work" exist (original, rebase-1, rebase-2)
  # Should appear exactly once
  local output
  output="$(run_git_done --since=2025-01-15T00:00:00 --until=2025-01-16T00:00:00)"
  local count
  count="$(printf '%s' "$output" | grep -cF "Add feature work")"
  if [ "$count" -eq 1 ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL [rebase same day: should have commit exactly once]: found $count occurrences"
  fi
}

# ── Test 9: Rebase spanning multiple days ────────────────────────

test_rebase_multi_day() {
  echo "-- test_rebase_multi_day"
  setup_repo

  # Base commit
  echo "base" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-14 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-14 10:00:00 +0000" \
  git commit -q -m "Base commit"

  # Feature branch: commit authored on Jan 15
  git checkout -q -b feature
  echo "feature work" > feature.txt
  git add feature.txt
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Add feature work"
  local old_hash
  old_hash="$(git rev-parse HEAD)"

  # Main gets a commit on Jan 16
  git checkout -q main
  echo "main work" > main.txt
  git add main.txt
  GIT_AUTHOR_DATE="2025-01-16 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-16 10:00:00 +0000" \
  git commit -q -m "Main work"

  # Rebase feature onto main on Jan 17
  git checkout -q feature
  GIT_COMMITTER_DATE="2025-01-17 09:00:00 +0000" \
  git rebase -q main
  git branch pre-rebase "$old_hash"

  # Jan 15 only: should show the commit (authored that day)
  local output_day1
  output_day1="$(run_git_done --since=2025-01-15T00:00:00 --until=2025-01-16T00:00:00)"
  assert_contains "multi-day rebase: day 1 has commit" "$output_day1" "Add feature work"

  # Jan 17 only: should NOT show it (just a rebase, not new work)
  local output_day3
  output_day3="$(run_git_done --since=2025-01-17T00:00:00 --until=2025-01-18T00:00:00)"
  assert_not_contains "multi-day rebase: rebase day should not have commit" "$output_day3" "Add feature work"

  # Full span Jan 15–18: should show exactly once
  local output_span
  output_span="$(run_git_done --since=2025-01-15T00:00:00 --until=2025-01-18T00:00:00)"
  local count
  count="$(printf '%s' "$output_span" | grep -cF "Add feature work")"
  if [ "$count" -eq 1 ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL [multi-day rebase: spanning range should have commit exactly once]: found $count occurrences"
  fi
}

# ── Run all tests ─────────────────────────────────────────────────

test_basic_formatting
test_no_body
test_backticks_in_patch
test_backticks_in_body
test_headings_in_body
test_both_escapes
test_rebase_dedup
test_rebase_same_day
test_rebase_multi_day

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
