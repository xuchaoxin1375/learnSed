#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Script: check-env.sh
# Purpose: Check that GNU sed and the tutorial data files are available.
# Usage:   bash scripts/check-env.sh [--help]
# =============================================================================

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
readonly ROOT

fail=0

usage() {
  cat <<'EOF'
Usage: bash scripts/check-env.sh [options]

Check the local sed implementation and the tutorial data files.

Options:
  -h, --help    Show this help and exit.

Exit status:
  0  GNU sed and all required data files are available.
  1  sed is missing, is not GNU sed, or data files are missing.
  2  Invalid command-line option.
EOF
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

error() {
  printf 'ERROR: %s\n' "$*" >&2
  fail=1
}

check_sed() {
  if ! command -v sed >/dev/null 2>&1; then
    error "sed not found in PATH"
    return
  fi

  printf 'sed path: %s\n' "$(command -v sed)"

  local version_output version_line
  version_output=$(sed --version 2>&1 || true)
  version_line=$(printf '%s\n' "$version_output" | head -n 1)
  printf 'sed version: %s\n' "$version_line"

  if printf '%s\n' "$version_output" | grep -q 'GNU sed'; then
    printf 'GNU sed: yes\n'
  else
    error "GNU sed is required; install gnu-sed (macOS: brew install gnu-sed) and use gsed"
  fi

  if printf 'a\n' | sed --debug 's/a/b/' >/dev/null 2>&1; then
    printf '%s\n' '--debug: yes'
  else
    warn "--debug is not available; the tutorial's debug examples need a newer GNU sed"
  fi

  if printf 'a\n' | sed -E 's/a/b/' >/dev/null 2>&1; then
    printf '%s\n' '-E: yes'
  else
    warn "-E is not available; this is unexpected for GNU sed"
  fi
}

check_locale() {
  printf 'locale: LC_ALL=%s LC_CTYPE=%s LANG=%s\n' \
    "${LC_ALL:-<unset>}" "${LC_CTYPE:-<unset>}" "${LANG:-<unset>}"

  case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    C | POSIX)
      warn "the current locale is C/POSIX; UTF-8 examples may process bytes instead of characters"
      ;;
  esac

  local width
  width=$(printf '中\n' | sed 's/./X/g' | wc -c | tr -d ' ' || printf '0')
  if [ "$width" -eq 2 ]; then
    printf 'utf8 matching: yes\n'
  else
    warn "sed appears to match bytes, not UTF-8 characters; set LC_ALL to an available UTF-8 locale (for example C.UTF-8) before the Unicode examples"
  fi
}

check_data() {
  local required_files=(
    "examples/data/hosts.txt"
    "examples/data/access.log"
    "examples/data/config.ini"
    "examples/data/dirty.txt"
    "examples/data/users.csv"
    "examples/data/poem.txt"
    "examples/data/employees.txt"
    "examples/data/paragraphs.txt"
    "examples/data/continuation.conf"
    "examples/data/block.txt"
    "examples/data/template.txt"
    "examples/data/unicode.txt"
    "examples/scripts/clean-hosts.sed"
  )
  local relative missing=0

  for relative in "${required_files[@]}"; do
    if [ ! -f "$ROOT/$relative" ]; then
      error "missing data file: $relative"
      missing=1
    fi
  done

  if [ "$missing" -eq 0 ]; then
    printf 'data files: yes (%s checked)\n' "${#required_files[@]}"
  fi
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

  printf 'learn-sed environment check\n'
  printf 'platform: %s\n' "$(uname -s 2>/dev/null || printf unknown)"
  printf 'repository: %s\n' "$ROOT"

  check_sed
  check_locale
  check_data

  if [ "$fail" -ne 0 ]; then
    printf 'result: FAIL\n'
    return 1
  fi

  printf 'result: OK\n'
  printf 'next: bash scripts/verify.sh\n'
  return 0
}

main "$@"
