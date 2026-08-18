#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_UC="$ROOT_DIR/forkop/files/usr/lib/subscription/cache.uc"
FORKOP_LIB="$ROOT_DIR/forkop/files/usr/lib"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  local label="$3"

  grep -Fq "$expected" "$file" || fail "$label: expected '$expected'"
}

mkdir -p "$WORK_DIR/bin"
cat >"$WORK_DIR/bin/curl" <<'CURL'
#!/bin/sh
printf '%s\n' "$*" >>"$CURL_LOG"
out=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then
    out="$arg"
  fi
  prev="$arg"
done
if [ -n "$out" ]; then
  printf '%s' '{"outbounds":[{"type":"socks","tag":"t","server":"1.2.3.4","server_port":1080}]}' >"$out"
fi
exit 0
CURL
chmod +x "$WORK_DIR/bin/curl"

cache_ucode() {
  PATH="$WORK_DIR/bin:$PATH" \
    FORKOP_UCI_STATE_FILE="$STATE_FILE" \
    TMP_SUBSCRIPTION_FOLDER="$WORK_DIR/subscriptions" \
    FORKOP_RUNTIME_STATE_DIR="$WORK_DIR/run" \
    FORKOP_SUBSCRIPTION_UPDATE_STATE_DIR="$WORK_DIR/update-state" \
    CURL_LOG="$CURL_LOG" \
    ucode -L "$FORKOP_LIB" "$CACHE_UC" "$@"
}

cat >"$WORK_DIR/insecure.state" <<'EOF_UCI'
forkop.proxy=section
forkop.proxy.enabled=1
forkop.proxy.subscription_urls=https://example.com/sub
forkop.proxy.subscription_url_settings={"https://example.com/sub":{"subscription_insecure":"1"}}
EOF_UCI
STATE_FILE="$WORK_DIR/insecure.state"
CURL_LOG="$WORK_DIR/insecure-curl.log"
: > "$CURL_LOG"
cache_ucode update-source proxy 1 'https://example.com/sub' runtime '' ||
  fail "insecure subscription download should succeed"
assert_contains "$CURL_LOG" ' -k ' "insecure download must pass -k to curl"

cat >"$WORK_DIR/secure.state" <<'EOF_UCI'
forkop.proxy=section
forkop.proxy.enabled=1
forkop.proxy.subscription_urls=https://example.com/sub
forkop.proxy.subscription_url_settings={"https://example.com/sub":{"subscription_insecure":"0"}}
EOF_UCI
STATE_FILE="$WORK_DIR/secure.state"
CURL_LOG="$WORK_DIR/secure-curl.log"
: > "$CURL_LOG"
status=0
cache_ucode update-source proxy 1 'https://example.com/sub' runtime '' || status=$?
if [ "$status" -ne 0 ] && [ "$status" -ne 2 ]; then
  fail "secure subscription download should succeed"
fi
if grep -Fq ' -k ' "$CURL_LOG"; then
  fail "secure download must not pass -k to curl"
fi

printf 'subscription insecure checks passed\n'
