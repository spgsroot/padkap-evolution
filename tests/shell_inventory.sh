#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PADKAP_EVOLUTION_FILES="$ROOT_DIR/padkap-evolution/files"
PADKAP_EVOLUTION_BIN="$PADKAP_EVOLUTION_FILES/usr/bin/padkap-evolution"
PADKAP_EVOLUTION_LIB="$PADKAP_EVOLUTION_FILES/usr/lib"
PADKAP_EVOLUTION_INIT="$PADKAP_EVOLUTION_FILES/etc/init.d/padkap-evolution"
LUCI_ROOT="$ROOT_DIR/luci-app-padkap-evolution/root"
LUCI_UCI_DEFAULTS="$LUCI_ROOT/etc/uci-defaults/50_luci-padkap-evolution"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -d "$PADKAP_EVOLUTION_LIB" ] || fail "runtime library directory is missing"
[ -r "$PADKAP_EVOLUTION_BIN" ] || fail "padkap-evolution ucode entrypoint is missing"
[ -r "$PADKAP_EVOLUTION_INIT" ] || fail "padkap-evolution init.d entrypoint is missing"
[ -r "$LUCI_UCI_DEFAULTS" ] || fail "LuCI uci-defaults entrypoint is missing"

runtime_shell_files="$(find "$PADKAP_EVOLUTION_LIB" -type f -name '*.sh' -print)"
[ -z "$runtime_shell_files" ] ||
  fail "runtime library must not contain shell owners: $runtime_shell_files"

legacy_shell_owners='runtime_state\.sh|rules_nft_runtime\.sh|config_validation\.sh|sing_box_runtime\.sh|updates_runtime\.sh|updater\.sh|status_diagnostics\.sh|helpers\.sh|constants\.sh|subscription_runtime\.sh|byedpi\.sh|zapret\.sh|zapret2\.sh'
if find "$PADKAP_EVOLUTION_FILES" -type f -print | grep -E "$legacy_shell_owners" >/dev/null 2>&1; then
  fail "legacy runtime shell owner file returned under padkap-evolution/files"
fi

shell_scripts="$(
  find "$PADKAP_EVOLUTION_FILES" "$LUCI_ROOT" -type f -print |
    while IFS= read -r file; do
      first_line="$(sed -n '1p' "$file")"
      case "$first_line" in
        '#!'*'/bin/sh'*|'#!'*'/bin/ash'*|'#!'*'rc.common'*|'#!'*' bash'*|'#!'*'/bash'*)
          printf '%s\n' "${file#$ROOT_DIR/}"
          ;;
      esac
    done |
    LC_ALL=C sort
)"

expected_shell_scripts="$(
  printf '%s\n' \
    'luci-app-padkap-evolution/root/etc/uci-defaults/50_luci-padkap-evolution' \
    'padkap-evolution/files/etc/init.d/padkap-evolution' |
    LC_ALL=C sort
)"

[ "$shell_scripts" = "$expected_shell_scripts" ] ||
  fail "unexpected packaged shell inventory:
expected:
$expected_shell_scripts
actual:
$shell_scripts"

grep -Fq '#!/usr/bin/ucode' "$PADKAP_EVOLUTION_BIN" ||
  fail "/usr/bin/padkap-evolution must remain a direct ucode executable"
grep -Fq 'function command_spec(command)' "$PADKAP_EVOLUTION_BIN" ||
  fail "/usr/bin/padkap-evolution must own command routing in ucode"
if grep -n -E '#!/bin/(ba)?sh|exec[[:space:]]+ucode|run_module\(|PADKAP_EVOLUTION_COMMAND' "$PADKAP_EVOLUTION_BIN" >/dev/null 2>&1; then
  fail "/usr/bin/padkap-evolution must not regress to a shell loader or shell router"
fi

grep -Fq 'PADKAP_EVOLUTION_INITD_UC="$PADKAP_EVOLUTION_LIB/service/initd.uc"' "$PADKAP_EVOLUTION_INIT" ||
  fail "init.d must delegate service orchestration to service/initd.uc"
grep -Fq 'initd_ucode start-service' "$PADKAP_EVOLUTION_INIT" ||
  fail "init.d start path must delegate to ucode"
grep -Fq 'initd_ucode stop-service' "$PADKAP_EVOLUTION_INIT" ||
  fail "init.d stop path must delegate to ucode"
grep -Fq 'initd_ucode reload-service' "$PADKAP_EVOLUTION_INIT" ||
  fail "init.d reload path must delegate to ucode"
grep -Fq 'initd_ucode trigger-plan' "$PADKAP_EVOLUTION_INIT" ||
  fail "init.d trigger decisions must be produced by ucode"

if grep -n -E '(^|[^[:alnum:]_])(uci|config_load|config_get|config_foreach|jsonfilter|nft|iptables|ip6?tables|sing-box|dnsmasq|curl|wget|opkg|apk)([[:space:]]|$)' "$PADKAP_EVOLUTION_INIT" >/dev/null 2>&1; then
  fail "init.d must not own UCI, routing, download, package, dnsmasq, nft, or sing-box decisions"
fi
if grep -n -E 'PADKAP_EVOLUTION_RELOAD_LOCK|PADKAP_EVOLUTION_URLTEST_SELECTOR_SWITCHES|capture_reload_state|populate_nft_runtime_sets|rebuild_nft_runtime|apply_pending_urltest_selector_switches' "$PADKAP_EVOLUTION_INIT" >/dev/null 2>&1; then
  fail "init.d must not own runtime state or reload decisions"
fi

grep -Fq '/usr/bin/padkap-evolution luci_postinst' "$LUCI_UCI_DEFAULTS" ||
  fail "LuCI uci-defaults must delegate postinstall work to ucode"
if grep -n -E '(^|[^[:alnum:]_])(uci|rm|logger|rpcd|killall|jsonfilter|config_load|config_get)([[:space:]]|$)' "$LUCI_UCI_DEFAULTS" >/dev/null 2>&1; then
  fail "LuCI uci-defaults must not own cache, rpcd, logging, or UCI logic"
fi

printf 'shell inventory checks passed\n'
