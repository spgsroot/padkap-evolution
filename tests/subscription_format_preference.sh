#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_UC="$ROOT_DIR/padkap-evolution/files/usr/lib/subscription/cache.uc"
PADKAP_EVOLUTION_LIB="$ROOT_DIR/padkap-evolution/files/usr/lib"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_first_line() {
  local file="$1"
  local expected="$2"
  local label="$3"

  [ "$(head -n 1 "$file")" = "$expected" ] ||
    fail "$label: expected '$expected', got '$(head -n 1 "$file")'"
}

cache_ucode() {
  ucode -L "$PADKAP_EVOLUTION_LIB" "$CACHE_UC" "$@"
}

cache_ucode write-user-agent-candidates \
  "$WORK_DIR/auto.txt" "" "" "sing-box/unknown" "auto"
assert_first_line "$WORK_DIR/auto.txt" "sing-box/unknown" \
  "auto preference must keep the sing-box client first"

cache_ucode write-user-agent-candidates \
  "$WORK_DIR/singbox.txt" "" "" "sing-box/unknown" "singbox"
assert_first_line "$WORK_DIR/singbox.txt" "sing-box/unknown" \
  "singbox preference must keep the sing-box client first"

cache_ucode write-user-agent-candidates \
  "$WORK_DIR/xray.txt" "" "" "sing-box/unknown" "xray"
assert_first_line "$WORK_DIR/xray.txt" "Happ/1.0.0" \
  "xray preference must front-load Xray JSON client profiles"
grep -Fxq "sing-box/unknown" "$WORK_DIR/xray.txt" ||
  fail "xray preference must keep the default client as a fallback"
grep -Fxq "v2rayNG/1.9.0" "$WORK_DIR/xray.txt" ||
  fail "xray preference must include all Xray JSON profiles"

cache_ucode write-user-agent-candidates \
  "$WORK_DIR/unknown.txt" "" "" "sing-box/unknown" "whatever"
assert_first_line "$WORK_DIR/unknown.txt" "sing-box/unknown" \
  "unknown preference must fall back to the default order"

cache_ucode write-user-agent-candidates \
  "$WORK_DIR/configured.txt" "Custom/1.0" "cached" "sing-box/unknown" "xray"
assert_first_line "$WORK_DIR/configured.txt" "Custom/1.0" \
  "configured user agent must outrank the format preference"

printf 'subscription format preference checks passed\n'
