# Memory — shell-backend-developer

Durable backend (ash + jq) knowledge. Read before implementing; append
findings; keep under ~200 lines.

## Hard constraints (proven)

- **OpenWRT jq has NO Oniguruma** — `test()`, `match()`, `sub()`, `gsub()` and
  any regex are unavailable. The updater (`updater.sh`) documents workarounds.
  Build string logic with `split`/`startswith`/`endswith`/`contains`/`ascii`
  instead.
- **`fatal` is only a log label** — `log "..." "fatal"` does NOT exit. You must
  follow it with `exit 1` yourself. Missing the `exit 1` continues with a
  half-built config.
- **busybox sed lacks `\x` escapes** — use printf-octal workarounds (see
  `helpers.sh` `convert_crlf_to_lf` and BOM stripping). Don't assume GNU sed.
- **Diagnostic strings are UTF-8, NOT mojibake** (corrected by task-004). The
  emoji/box-drawing in `usr/bin/netshift` (`global_check`, `list_update`,
  `subscription_update`, `check_nft`: `📡 🛠️ ✅ ❌ ⚠️ ➡️ 🧱 🥸 📄 ━`) are valid
  UTF-8 and must STAY valid UTF-8. They were once double-encoded (UTF-8 read as
  CP1251, re-saved as UTF-8 → printed `рџ…`/`в”…`/`вЂ…`). Never open/save that file
  in a non-UTF-8 editor or pass it through CP1251 — it re-corrupts. The earlier
  "preserve the corrupted bytes" note here was the WRONG guidance that protected
  the bug.

## Conventions (follow exactly)

- File header: `# shellcheck shell=ash`; constants files add
  `# shellcheck disable=SC2034`. Declare every variable `local`.
- Function prefixes: `sing_box_cm_*` = one jq mutation each (dumb primitive);
  `sing_box_cf_*` = facade (parse + several cm_* calls); `url_*` = pure URL
  parsing; `is_*` = predicate returning 0/1; `nft_*` = nft wrapper; `updates_*`
  = updater; `get_*_tag` = deterministic tag builder; `configure_*`/`import_*`/
  `_*_handler` = config_foreach callbacks; leading `_` = private helper.
- Config threading: `$config` is a shell STRING; cm/cf take it as `$1`, echo
  mutated JSON; caller does `config=$(sing_box_cm_... "$config" ...)`.
- jq optional keys: `+ (if $x != "" then {k:$x} else {} end)`. Custom helpers
  in `helpers.jq`, imported `import "helpers" as h {"search":"/usr/lib/netshift"}`.
- Validation is mandatory: write to `*.tmp.$$`, run `sing-box -c <file> check`
  (fatal on fail), `jq -e` for shape, md5sum-compare, then `mv`. Atomic only.
- New constants -> `constants.sh` (grouped Common/nft/sing-box/Lists). Never
  hardcode ports/IPs/marks/paths.
- The service-tag pattern: cm_* functions stamp a transient `__service_tag`
  (`SERVICE_TAG`) on rules; `sing_box_cm_save_config_to_file` strips every
  `__service_tag` via `walk(...)` before writing. Don't leave tags in output.

## Subscription / unavailable-outbound flow (don't leak traffic)

- Many code paths branch on `subscription_outbound_is_unavailable` to emit
  **reject** route rules instead of routes when a subscription is down. Any new
  routing code MUST respect this or it leaks traffic when a sub is unavailable.

## Testing

- Smoke suite is `tests/entrypoint.sh` (run via `smoke-tests` skill). Categories:
  deps syntax config helpers jq cm sb nft diagnostics subscription.
- To add a test: write `test_xyz()` using the `header`/`pass`/`fail`/`skip`
  helpers; add it to `main()`'s `all)` list; add a `case` alias; update the
  usage line and the docker-compose comment. Config-gen and subscription
  parsing changes SHOULD get a smoke test.
- Pre-commit-equivalent: always run the `shellcheck` skill (severity error) on
  touched shell files before handing back.

## jq gotchas (proven by task-002)

- **`include` / `exclude` are RESERVED jq keywords** — you cannot name a jq
  variable `$include` (jq tries to parse the `include` directive). Use `$inc`/
  `$exc` etc. for keyword-filter lists.
- **`any(gen; cond)` / `all(gen; cond)` binding trap**: inside the condition,
  `.` is the generator element ONLY at the top of `cond`. If you write
  `($name | index(.))` the `.` becomes `$name` (the pipe rebinds `.`), so the
  match silently always succeeds. Bind first: `any($kw[]; . as $k | ($name |
  index($k)) != null)`.
- Subscription keyword filter lives in `sing_box_cf_prepare_subscription_batch`
  (facade), runs BEFORE static-unsupported filter + tag dedup, threaded from the
  `subscription)` branch via two UCI **list** options
  `subscription_filter_include_keywords` / `subscription_filter_exclude_keywords`
  (the cross-layer contract names for task-003 — do NOT rename). Keywords are
  opaque user text: collect with a `config_list_foreach` handler that jq
  `--arg`-appends each item into a JSON array (commas/emoji survive; never use
  `comma_string_to_json_array` for them). Empty result reuses the existing
  `mark_subscription_outbound_unavailable` fail-safe (no `exit 1`).

## Known landmines

- nft proxy chain hardcodes `127.0.0.1:1602` (duplicates the constants).
- VPN `domain_resolver` uses wrong variable `$dns_server`.
- `check_nft` references stale set names (`netshift_domains`) / UCI options that
  don't exist elsewhere — likely copied diagnostic cruft.

## task-004: double-encode repair recipe (reusable)

- To reverse a UTF-8→CP1251 double-encode losslessly: `text =
  bytes.decode("utf-8"); fixed = text.encode("cp1251").decode("utf-8")` then
  write `fixed.encode("utf-8")`. ASCII bytes pass through; verify 0
  cp1251-unmappable chars and that ASCII-stripped lines are byte-identical
  before/after (proves no code moved). Result was exactly 114 lines, all
  non-ASCII-only. LF/no-BOM preserved.
- On Windows here, `python3.exe` is the MS Store stub — use `python` (Python
  3.11 at `...\Programs\Python\Python311`). Don't `print()` emoji to the
  PowerShell console (cp1251 codepage mangles it / raises); write results to a
  UTF-8 file and read it back.
## task-005 review-001: vmess base64 + url_decode landmine (proven)

- `sing_box_cf_add_proxy_outbound` runs `url=$(url_decode "$url")` BEFORE the
  scheme `case`, and `url_decode` does `s/+/ /g`. Any scheme that base64-decodes
  the WHOLE payload (vmess `vmess://base64(JSON)`; future tuic/etc.) MUST decode
  from the RAW link, not the url_decode'd one — standard base64's alphabet
  includes `+`, so `+`→space corrupts ~1-in-64 real keys. Fix pattern: capture
  `local raw_url="$3"` at the top (before url_decode) and pass `$raw_url` to the
  whole-payload decoder. Other scheme cases keep using the url_decode'd `$url`.
- **busybox `tr` does NOT support POSIX char classes** — `tr -d '[:space:]'`
  deletes the LITERAL chars `[ : s p a c e ]` (silently corrupts base64!). Use
  explicit bytes: `tr -d ' \011\012\015'` (space/tab/LF/CR octal). Verified
  in-container: input `aZ:[]cept123` → `Zt123` with `[:space:]`. This was a real
  regression I introduced and caught via the `sb` smoke run.
- base64 padding normalization for unpadded links: right-pad payload length to a
  multiple of 4 with `=` using `pad=$(( ${#p} % 4 ))` then a `while` append loop.
  POSIX-safe, busybox-safe.
- To craft a base64 body that DELIBERATELY contains `+`: a `ps`/label value of
  `node>>` (bytes 0x3E 0x3E) forces a 6-bit group = 62 → `+`. Realistic ASCII
  host/word values rarely hit it; `>>` is reliable.
- Probing helpers in-container without fighting PowerShell quoting: write a tiny
  `.sh` into `netshift/files/usr/lib/` (it's bind-mounted into the smoke
  container at `/netshift/files`), run via
  `docker compose ... run --rm --entrypoint sh netshift-test /netshift/files/usr/lib/_tmp.sh`,
  then delete it. Inline `-c "..."` one-liners get mangled by PowerShell.

- `test_syntax` in `tests/entrypoint.sh` now also `ash -n`'s `usr/bin/netshift`
  and asserts no residual `рџ`/`в”`/`вЂ` markers (built via `printf` octal, since
  busybox grep lacks `\x`). Guards against re-introducing the mojibake.
