#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_DONE_DAILY="$SCRIPT_DIR/git-done-daily"

# git-done-daily invokes git-done by name, so it must be on PATH
export PATH="$SCRIPT_DIR:$PATH"

PASS=0
FAIL=0
TMPDIR=""
REPO_DIR=""
OUTPUT_DIR=""

setup_repo() {
  TMPDIR="$(mktemp -d)"
  REPO_DIR="$TMPDIR/repo"
  OUTPUT_DIR="$TMPDIR/output"
  mkdir -p "$REPO_DIR" "$OUTPUT_DIR"
  cd "$REPO_DIR"
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

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL [$label]: expected file to exist: $path"
  fi
}

assert_file_not_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL [$label]: expected file NOT to exist: $path"
  else
    PASS=$((PASS + 1))
  fi
}

assert_file_contains() {
  local label="$1" path="$2" needle="$3"
  if [ ! -f "$path" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL [$label]: file does not exist: $path"
    return
  fi
  if grep -qF "$needle" "$path"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL [$label]: expected file to contain: $needle"
  fi
}

assert_stdout_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL [$label]: expected stdout to contain: $needle"
  fi
}

assert_stdout_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    FAIL=$((FAIL + 1))
    echo "FAIL [$label]: expected stdout NOT to contain: $needle"
  else
    PASS=$((PASS + 1))
  fi
}

run_daily() {
  cd "$OUTPUT_DIR"
  GIT_DONE_AUTHOR="Test User" "$GIT_DONE_DAILY" -C "$REPO_DIR" "$@"
}

# ── Test 1: Separate files per day ─────────────────────────────────

test_files_per_day() {
  echo "-- test_files_per_day"
  setup_repo

  echo "day1" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Work on day one"

  echo "day2" >> file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-16 14:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-16 14:00:00 +0000" \
  git commit -q -m "Work on day two"

  local stdout
  stdout="$(run_daily --since 2025-01-15 --until 2025-01-16)"

  assert_file_exists     "day1 file created" "$OUTPUT_DIR/2025-01-15-repo.md"
  assert_file_exists     "day2 file created" "$OUTPUT_DIR/2025-01-16-repo.md"
  assert_file_contains   "day1 content"      "$OUTPUT_DIR/2025-01-15-repo.md" "Work on day one"
  assert_file_contains   "day2 content"      "$OUTPUT_DIR/2025-01-16-repo.md" "Work on day two"
  assert_stdout_contains "day1 printed"      "$stdout" "2025-01-15-repo.md"
  assert_stdout_contains "day2 printed"      "$stdout" "2025-01-16-repo.md"
}

# ── Test 2: Empty day produces no file ─────────────────────────────

test_empty_day_no_file() {
  echo "-- test_empty_day_no_file"
  setup_repo

  echo "only" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Only commit"

  local stdout
  stdout="$(run_daily --since 2025-01-15 --until 2025-01-16)"

  assert_file_exists       "day with commit"    "$OUTPUT_DIR/2025-01-15-repo.md"
  assert_file_not_exists   "empty day no file"  "$OUTPUT_DIR/2025-01-16-repo.md"
  assert_stdout_not_contains "empty day not printed" "$stdout" "2025-01-16-repo.md"
}

# ── Test 3: --name overrides filename ──────────────────────────────

test_name_override() {
  echo "-- test_name_override"
  setup_repo

  echo "x" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Named commit"

  local stdout
  stdout="$(run_daily --since 2025-01-15 --until 2025-01-15 --name myproject)"

  assert_file_exists     "custom name"  "$OUTPUT_DIR/2025-01-15-myproject.md"
  assert_file_not_exists "no default"   "$OUTPUT_DIR/2025-01-15-repo.md"
  assert_stdout_contains "name in stdout" "$stdout" "2025-01-15-myproject.md"
}

# ── Test 4: -C flag runs in another directory ──────────────────────

test_c_flag() {
  echo "-- test_c_flag"
  setup_repo

  echo "remote" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "Remote repo commit"

  # Run from output dir, pointing -C at the repo
  cd "$OUTPUT_DIR"
  local stdout
  stdout="$(GIT_DONE_AUTHOR="Test User" "$GIT_DONE_DAILY" -C "$REPO_DIR" --since 2025-01-15 --until 2025-01-15)"

  assert_file_exists   "file in output dir" "$OUTPUT_DIR/2025-01-15-repo.md"
  assert_file_contains "correct content"    "$OUTPUT_DIR/2025-01-15-repo.md" "Remote repo commit"
}

# ── Test 5: Flexible --since granularity (YYYY-MM) ────────────────

test_since_month_granularity() {
  echo "-- test_since_month_granularity"
  setup_repo

  echo "jan" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-20 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-20 10:00:00 +0000" \
  git commit -q -m "January commit"

  # --since 2025-01 should expand to 2025-01-01
  run_daily --since 2025-01 --until 2025-01-31 > /dev/null

  assert_file_exists   "month granularity" "$OUTPUT_DIR/2025-01-20-repo.md"
  assert_file_contains "correct commit"    "$OUTPUT_DIR/2025-01-20-repo.md" "January commit"
}

# ── Test 6: Flexible --until granularity (YYYY-MM) ────────────────

test_until_month_granularity() {
  echo "-- test_until_month_granularity"
  setup_repo

  echo "late" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-31 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-31 10:00:00 +0000" \
  git commit -q -m "End of month commit"

  # --until 2025-01 should expand to 2025-01-31
  run_daily --since 2025-01-30 --until 2025-01 > /dev/null

  assert_file_exists   "until month includes last day" "$OUTPUT_DIR/2025-01-31-repo.md"
  assert_file_contains "correct commit"                "$OUTPUT_DIR/2025-01-31-repo.md" "End of month commit"
}

# ── Test 7: Pass-through args after -- ─────────────────────────────

test_passthrough_args() {
  echo "-- test_passthrough_args"
  setup_repo

  echo "a" > file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-15 10:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 10:00:00 +0000" \
  git commit -q -m "First commit of day"

  echo "b" >> file.txt
  git add file.txt
  GIT_AUTHOR_DATE="2025-01-15 14:00:00 +0000" \
  GIT_COMMITTER_DATE="2025-01-15 14:00:00 +0000" \
  git commit -q -m "Second commit of day"

  # Without -1, both commits should appear
  run_daily --since 2025-01-15 --until 2025-01-15 > /dev/null
  assert_file_contains "both commits" "$OUTPUT_DIR/2025-01-15-repo.md" "First commit of day"
  assert_file_contains "both commits" "$OUTPUT_DIR/2025-01-15-repo.md" "Second commit of day"
}

# ── Run all tests ─────────────────────────────────────────────────

test_files_per_day
test_empty_day_no_file
test_name_override
test_c_flag
test_since_month_granularity
test_until_month_granularity
test_passthrough_args

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
