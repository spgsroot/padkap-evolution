#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PADKAP_EVOLUTION_BIN="$ROOT_DIR/padkap-evolution/files/usr/bin/padkap-evolution"
PADKAP_EVOLUTION_LIB="$ROOT_DIR/padkap-evolution/files/usr/lib"
CLI_UC="$PADKAP_EVOLUTION_BIN"
PADKAP_EVOLUTION_MAKEFILE="$ROOT_DIR/padkap-evolution/Makefile"
BUILD_SCRIPT="$ROOT_DIR/build.sh"
CONSTANTS_SH="$PADKAP_EVOLUTION_LIB/constants.sh"
LIFECYCLE_UC="$PADKAP_EVOLUTION_LIB/service/lifecycle.uc"
CONSTANTS_UC="$PADKAP_EVOLUTION_LIB/core/constants.uc"
SINGBOX_CONSTANTS_UC="$PADKAP_EVOLUTION_LIB/singbox/constants.uc"
FRONTEND_CONSTANTS="$ROOT_DIR/fe-app-padkap-evolution/src/constants.ts"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ ! -e "$CONSTANTS_SH" ] ||
  fail "constants.sh shell owner must be removed"

grep -Fq '#!/usr/bin/ucode' "$PADKAP_EVOLUTION_BIN" ||
  fail "padkap-evolution entrypoint must be a direct ucode executable"
grep -Fq 'service/lifecycle.uc' "$CLI_UC" ||
  fail "service/cli.uc must dispatch lifecycle orchestration through service/lifecycle.uc"
grep -Fq 'core.constants' "$LIFECYCLE_UC" ||
  fail "service/lifecycle.uc must load constants from core/constants.uc"

if grep -R -n -E 'constants\.sh|read_shell_constants|expand_shell_constants|unquote_shell_value' \
  "$PADKAP_EVOLUTION_BIN" "$PADKAP_EVOLUTION_LIB" --include='*.sh' --include='*.uc' >/dev/null 2>&1; then
  fail "shell constants owner or parser references must not remain"
fi

if grep -n 'constants\.sh' "$PADKAP_EVOLUTION_MAKEFILE" "$BUILD_SCRIPT" >/dev/null 2>&1; then
  fail "package build must not patch removed constants.sh"
fi
grep -Fq 'core/constants.uc' "$PADKAP_EVOLUTION_MAKEFILE" ||
  fail "padkap-evolution/Makefile must patch core/constants.uc"
grep -Fq 'core/constants.uc' "$BUILD_SCRIPT" ||
  fail "release build must patch core/constants.uc"

config_name="$(ucode -L "$PADKAP_EVOLUTION_LIB" "$CONSTANTS_UC" get PADKAP_EVOLUTION_CONFIG_NAME)"
[ "$config_name" = "padkap-evolution" ] ||
  fail "core/constants.uc get returned unexpected PADKAP_EVOLUTION_CONFIG_NAME"

eval "$(ucode -L "$PADKAP_EVOLUTION_LIB" "$CONSTANTS_UC" shell-env)"
[ "$PADKAP_EVOLUTION_CONFIG" = "/etc/config/padkap-evolution" ] ||
  fail "core/constants.uc shell-env did not derive PADKAP_EVOLUTION_CONFIG"
[ "$TMP_RULESET_FOLDER" = "/tmp/sing-box/rulesets" ] ||
  fail "core/constants.uc shell-env did not derive TMP_RULESET_FOLDER"
[ "$BYEDPI_PID_DIR" = "/var/run/padkap-evolution/byedpi/pid" ] ||
  fail "core/constants.uc shell-env did not derive BYEDPI_PID_DIR"

[ "$(ucode -L "$PADKAP_EVOLUTION_LIB" "$CONSTANTS_UC" get FAKEIP_TEST_DOMAIN)" = "fakeip.podkop.fyi" ] ||
  fail "FakeIP diagnostics must use the deployed public endpoint"
[ "$(ucode -L "$PADKAP_EVOLUTION_LIB" "$CONSTANTS_UC" get CHECK_PROXY_IP_DOMAIN)" = "ip.podkop.fyi" ] ||
  fail "public IP diagnostics must use the deployed public endpoint"
grep -Fq 'const FAKEIP_TEST_DOMAIN = "fakeip.podkop.fyi";' "$SINGBOX_CONSTANTS_UC" ||
  fail "sing-box constants must match the deployed FakeIP endpoint"
grep -Fq "export const FAKEIP_CHECK_DOMAIN = 'fakeip.podkop.fyi';" "$FRONTEND_CONSTANTS" ||
  fail "LuCI diagnostics must use the deployed FakeIP endpoint"
grep -Fq "export const IP_CHECK_DOMAIN = 'ip.podkop.fyi';" "$FRONTEND_CONSTANTS" ||
  fail "LuCI diagnostics must use the deployed public IP endpoint"

printf 'constants ownership checks passed\n'
