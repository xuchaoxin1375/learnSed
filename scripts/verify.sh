#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Script: verify.sh
# Purpose: Run regression checks for the tutorial's GNU sed examples.
# Usage:   bash scripts/verify.sh [--help]
# =============================================================================

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
readonly ROOT

TMP_DIR=""
pass_count=0
fail_count=0

usage() {
  cat <<'EOF'
Usage: bash scripts/verify.sh [options]

Run assertions for the core behaviours taught in the tutorial.
The script uses a temporary directory and does not modify repository files.

Options:
  -h, --help    Show this help and exit.

Exit status:
  0  All checks passed.
  1  At least one check failed, or GNU sed is unavailable.
  2  Invalid command-line option.
EOF
}

cleanup() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}

pass() {
  pass_count=$((pass_count + 1))
  printf 'PASS  %s\n' "$1"
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL  %s\n' "$1" >&2
}

assert_eq() {
  local name expected actual
  name=$1
  expected=$2
  actual=$3

  if [ "$expected" = "$actual" ]; then
    pass "$name"
  else
    fail "$name"
    printf '      expected: %q\n' "$expected" >&2
    printf '      actual:   %q\n' "$actual" >&2
  fi
}

run_checks() {
  assert_eq "s replaces only the first match" \
    "blue red red" \
    "$(printf 'red red red\n' | sed 's/red/blue/')"

  assert_eq "s/g replaces every match" \
    "blue blue blue" \
    "$(printf 'red red red\n' | sed 's/red/blue/g')"

  assert_eq "s/2g starts at the second match" \
    "red blue blue" \
    "$(printf 'red red red\n' | sed 's/red/blue/2g')"

  assert_eq "-n with p selects one line" \
    "b" \
    "$(printf 'a\nb\nc\n' | sed -n '2p')"

  assert_eq "d removes the selected line" \
    $'a\nc' \
    "$(printf 'a\nb\nc\n' | sed '2d')"

  assert_eq "s/^/prefix/ prefixes every line" \
    $'> a\n> b' \
    "$(printf 'a\nb\n' | sed 's/^/> /')"

  assert_eq "a range includes its ending line" \
    $'b\nc' \
    "$(printf 'a\nb\nc\nd\n' | sed -n '/b/,/c/p')"

  assert_eq "a range does not test its end regex on the start line" \
    $'aaa\nbbb' \
    "$(printf 'aaa\nbbb\n' | sed -n '/aaa/,/aaa/p')"

  assert_eq "0,/re/ can stop on the first line" \
    $'a=0\na=2' \
    "$(printf 'a=1\na=2\n' | sed '0,/^a=/s/=.*/=0/')"

  assert_eq "address negation prints the other lines" \
    "b" \
    "$(printf 'a\nb\n' | sed -n '/a/!p')"

  assert_eq "backslash ampersand is literal in the replacement" \
    "a[&]c" \
    "$(printf 'abc\n' | sed 's/b/[\&]/')"

  assert_eq "y maps characters one by one" \
    "xyz" \
    "$(printf 'abc\n' | sed 'y/abc/xyz/')"

  printf 'a\nb\n' >"$TMP_DIR/one.txt"
  printf 'c\nd\n' >"$TMP_DIR/two.txt"
  assert_eq "-s makes $ mean the last line of each file" \
    $'b\nd' \
    "$(sed -n -s '$p' "$TMP_DIR/one.txt" "$TMP_DIR/two.txt")"

  printf 'foo\n' >"$TMP_DIR/inplace.txt"
  sed -i.bak 's/foo/bar/' "$TMP_DIR/inplace.txt"
  assert_eq "-i.bak updates the file" \
    "bar" \
    "$(sed -n '1p' "$TMP_DIR/inplace.txt")"
  assert_eq "-i.bak keeps the original content" \
    "foo" \
    "$(sed -n '1p' "$TMP_DIR/inplace.txt.bak")"

  assert_eq "hold space reverses a file" \
    $'3\n2\n1' \
    "$(printf '1\n2\n3\n' | sed -n '1!G;h;$p')"

  assert_eq "hold space removes non-adjacent duplicates" \
    $'alice\nbob\ncarol\ndave' \
    "$(sed -n 'G;/^\(.*\)\n\(.*\n\)*\1$/d;P;H' examples/data/employees.txt)"

  assert_eq "N joins continuation lines" \
    $'DATABASE_URL=postgres://db:5432/app ?sslmode=require\nCACHE_URL=redis://cache:6379/0' \
    "$(sed -e :a -e '/\\$/N' -e 's/[[:space:]]*\\\n[[:space:]]*/ /' -e 'ta' examples/data/continuation.conf)"

  assert_eq "hold space joins paragraphs" \
    $'Sed reads input line by line. It keeps the current line in the pattern space.\nMultiple lines can be joined with N. The hold space survives across cycles.\nThis is the last paragraph.' \
    "$(sed -n '/./{H;$!d};x;s/^\n//;s/\n/ /g;p' examples/data/paragraphs.txt)"

  assert_eq "N;P;D implements a sliding window" \
    $'a\nb\nc' \
    "$(printf 'a\nb\nc\nd\n' | sed -n 'N;P;D')"

  assert_eq "a guarded N keeps the last line" \
    $'a\nb\nc\nd' \
    "$(printf 'a\nb\nc\nd\n' | sed -n '$!N;P;D')"

  assert_eq "the log contains two 5xx lines" \
    "2" \
    "$(sed -nE '/" 5[0-9]{2} /p' examples/data/access.log | wc -l | tr -d ' ')"

  assert_eq "the last IPv4 octet can be masked" \
    "203.0.113.xxx - x" \
    "$(printf '203.0.113.10 - x\n' | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+\.)[0-9]+/\1xxx/')"

  assert_eq "simple CSV fields can be reordered" \
    "Alice,1,x" \
    "$(printf '1,Alice,x\n' | sed -E 's/^([^,]+),([^,]+),/\2,\1,/')"

  assert_eq "a sed script file can clean comments and blank lines" \
    "a b" \
    "$(printf '# comment\n\na   b\n' | sed -f examples/scripts/clean-hosts.sed)"

  q_status=$(
    set +e
    printf 'a\nb\n' | sed '1q 5' >/dev/null 2>&1
    printf '%s' "$?"
  )
  assert_eq "q can set an exit status" "5" "$q_status"

  assert_eq "Q exits without printing" \
    "" \
    "$(printf 'a\n' | sed 'Q')"

  printf 'a\n' >"$TMP_DIR/s1.txt"
  printf 'b\n' >"$TMP_DIR/s2.txt"
  sed -i '$a\X' "$TMP_DIR/s1.txt" "$TMP_DIR/s2.txt"
  assert_eq "-i treats each file separately (first file)" \
    $'a\nX' \
    "$(cat "$TMP_DIR/s1.txt")"
  assert_eq "-i treats each file separately (second file)" \
    $'b\nX' \
    "$(cat "$TMP_DIR/s2.txt")"
}

main() {
  case "${1:-}" in
    -h | --help)
      usage
      return 0
      ;;
    "")
      ;;
    *)
      printf 'ERROR: unknown option: %s\n' "$1" >&2
      usage >&2
      return 2
      ;;
  esac

  if ! sed --version 2>&1 | grep -q 'GNU sed'; then
    printf 'ERROR: GNU sed is required; run bash scripts/check-env.sh\n' >&2
    return 1
  fi

  cd "$ROOT" || {
    printf 'ERROR: cannot enter repository root: %s\n' "$ROOT" >&2
    return 1
  }

  TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/learn-sed.XXXXXX") || {
    printf 'ERROR: cannot create temporary directory\n' >&2
    return 1
  }
  trap cleanup EXIT

  printf 'learn-sed verification\n'
  printf 'sed: %s\n' "$(sed --version 2>/dev/null | head -n 1)"

  run_checks

  printf '\n'
  printf 'checks passed: %s\n' "$pass_count"
  printf 'checks failed: %s\n' "$fail_count"

  if [ "$fail_count" -ne 0 ]; then
    printf 'result: FAIL\n' >&2
    return 1
  fi

  printf 'result: OK\n'
  return 0
}

main "$@"
