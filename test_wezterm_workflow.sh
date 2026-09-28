#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-configs-wezterm-test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
HOME_DIR="$TMP_ROOT/home"
FAKE_BIN="$TMP_ROOT/bin"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

HOME="$HOME_DIR" bash "$REPO_ROOT/wezterm/install.sh" >/dev/null

[[ -f "$HOME_DIR/.config/wezterm/ai-configs-remote-workflow.lua" ]]
[[ -x "$HOME_DIR/.local/bin/wezterm-paste-image-to-ssh" ]]
[[ -x "$HOME_DIR/.local/bin/clipssh" ]]
rg -q '^-- BEGIN ai-configs wezterm remote workflow$' "$HOME_DIR/.wezterm.lua"
rg -q '^return config$' "$HOME_DIR/.wezterm.lua"
rg -q '^# BEGIN ai-configs wezterm remote workflow$' "$HOME_DIR/.zshrc"
[[ "$(grep -c '^-- BEGIN ai-configs wezterm remote workflow$' "$HOME_DIR/.wezterm.lua")" -eq 1 ]]

HOME="$HOME_DIR" bash "$REPO_ROOT/wezterm/install.sh" >/dev/null
[[ "$(grep -c '^-- BEGIN ai-configs wezterm remote workflow$' "$HOME_DIR/.wezterm.lua")" -eq 1 ]]
[[ "$(grep -c '^# BEGIN ai-configs wezterm remote workflow$' "$HOME_DIR/.zshrc")" -eq 1 ]]

# The shipped module has an empty HOST_COLORS (no remote hosts configured in
# this fork). Inject test host colors into a copy and exercise the mechanism
# against it; the shipped file must resolve no hosts.
PATCHED_LUA="$TMP_ROOT/remote-workflow.lua"
python3 - "$REPO_ROOT/wezterm/remote-workflow.lua" "$PATCHED_LUA" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
test_colors = """local HOST_COLORS = {
  mbp = { background = '#3B2E5A', active_background = '#594382', foreground = '#F0EAF7' },
  dever = { background = '#1E3A5F', active_background = '#2A5185', foreground = '#E6EDF3' },
  ['mbp14-2'] = { background = '#244436', active_background = '#32604D', foreground = '#E6F2EA' },
}"""
src, n = re.subn(r"local HOST_COLORS = \{.*?\n\}", test_colors, src, count=1, flags=re.S)
assert n == 1, "HOST_COLORS block not found in remote-workflow.lua"
open(sys.argv[2], "w").write(src)
PY

lua - "$PATCHED_LUA" "$REPO_ROOT/wezterm/remote-workflow.lua" <<'LUA'
local workflow = dofile(arg[1])
local shipped = dofile(arg[2])
local cases = {
  { 'Herdr (mbp) 2 / 1 / 3 [herdr-kitty bg=1e3a5f fg=e6edf3]', 'mbp', '#3B2E5A' },
  { 'Herdr (dever) 4 / 0 / 1 [herdr-kitty bg=3b2e5a fg=f0eaf7]', 'dever', '#1E3A5F' },
  { 'Herdr (mbp14-2) 1 / 0 / 0 [herdr-kitty bg=244436 fg=e6f2ea]', 'mbp14-2', '#244436' },
}
-- The shipped module configures no remote hosts, so it resolves none.
assert(shipped.parse_status_title(cases[1][1]) == nil)
for _, case in ipairs(cases) do
  local status = assert(workflow.parse_status_title(case[1]))
  assert(status.host == case[2])
  assert(status.colors.background == case[3])
  local rendered = workflow.format_tab_title(
    { truncate_right = function(value) return value end },
    { tab_title = '', active_pane = { title = case[1] } },
    36
  )
  assert(rendered[1].Background.Color == case[3])
  assert(rendered[2].Foreground.Color == status.colors.foreground)
  assert(rendered[3].Attribute.Intensity == 'Normal')
  assert(rendered[6].Foreground.Color == '#F9E2AF')
  assert(rendered[10].Foreground.Color == '#FAB387')
  assert(rendered[14].Foreground.Color == '#A6E3A1')
  for _, item in ipairs(rendered) do
    assert(item.Text ~= '● ')
  end
end
assert(workflow.parse_status_title('plain shell') == nil)
assert(workflow.parse_status_title('Herdr (unknown) 1 / 0 / 0') == nil)

local active = workflow.format_tab_title(
  { truncate_right = function(value) return value end },
  { tab_title = '', is_active = true, active_pane = { title = cases[1][1] } },
  36
)
assert(active[1].Background.Color == '#594382')
assert(active[3].Attribute.Intensity == 'Bold')
assert(active[5].Attribute.Intensity == 'Normal')

local events = {}
local fake_wezterm = {
  action = {
    SpawnCommandInNewWindow = function(value) return value end,
    SendString = function(value) return value end,
  },
  action_callback = function(callback) return callback end,
  on = function(name, callback) events[name] = callback end,
}
local config = {}
workflow.apply(config, fake_wezterm)
assert(config.enable_kitty_keyboard == true)
assert(config.use_fancy_tab_bar == false)
assert(config.tab_max_width == 36)
assert(events['format-tab-title'] ~= nil)
LUA

AMBIGUOUS_HOME="$TMP_ROOT/ambiguous-home"
mkdir -p "$AMBIGUOUS_HOME"
cat > "$AMBIGUOUS_HOME/.wezterm.lua" <<'LUA'
local wezterm = require 'wezterm'
return { }
LUA
if HOME="$AMBIGUOUS_HOME" bash "$REPO_ROOT/wezterm/install.sh" >/dev/null 2>&1; then
  echo 'expected ambiguous root config to be rejected' >&2
  exit 1
fi
rg -q '^return \{ \}$' "$AMBIGUOUS_HOME/.wezterm.lua"

cat > "$FAKE_BIN/clipssh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$CLIPSSH_LOG"
SH
cat > "$FAKE_BIN/pbpaste" <<'SH'
#!/usr/bin/env bash
printf '%s' '~/.cache/clipssh/test.png'
SH
cat > "$FAKE_BIN/wezterm" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$WEZTERM_LOG"
SH
chmod +x "$FAKE_BIN/clipssh" "$FAKE_BIN/pbpaste" "$FAKE_BIN/wezterm"

# The shipped allowlist is empty, so every host is rejected by default.
if PATH="$FAKE_BIN:$PATH" bash "$REPO_ROOT/wezterm/wezterm-paste-image-to-ssh" --host thump --pane-id 42 >/dev/null 2>&1; then
  echo 'expected unconfigured host to be rejected (no remote hosts configured)' >&2
  exit 1
fi

# Exercise the real transfer path by injecting a test host into the allowlist
# of a copied script.
PATCHED_PASTE="$TMP_ROOT/wezterm-paste-image-to-ssh"
sed 's@  # myhost1|myhost2) ;;@  thump) ;;@' "$REPO_ROOT/wezterm/wezterm-paste-image-to-ssh" > "$PATCHED_PASTE"
grep -q '^  thump) ;;$' "$PATCHED_PASTE"

PATH="$FAKE_BIN:$PATH" CLIPSSH_LOG="$TMP_ROOT/clipssh.log" WEZTERM_LOG="$TMP_ROOT/wezterm.log" \
  bash "$PATCHED_PASTE" --host thump --pane-id 42
[[ "$(<"$TMP_ROOT/clipssh.log")" == 'thump' ]]
rg -q '^cli send-text --pane-id 42 --no-paste$' "$TMP_ROOT/wezterm.log"

if PATH="$FAKE_BIN:$PATH" bash "$PATCHED_PASTE" --host invalid --pane-id 42 >/dev/null 2>&1; then
  echo 'expected unknown host to be rejected' >&2
  exit 1
fi

cat > "$FAKE_BIN/wezterm" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$HERDR_LAUNCH_LOG"
SH
cat > "$FAKE_BIN/kitten" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$HERDR_LAUNCH_LOG"
SH
chmod +x "$FAKE_BIN/wezterm" "$FAKE_BIN/kitten"
# The shipped fragment defines no herdr-<host> functions (no remote hosts
# configured). Verify none exist, then define a test host function the way a
# user would and check both launch paths still work.
PATH="$FAKE_BIN:$PATH" zsh -fc "source '$REPO_ROOT/wezterm/remote-workflow.zsh'; whence -w herdr-mbp herdr-dever" >/dev/null 2>&1 \
  && { echo 'expected no bundled herdr-<host> functions'; exit 1; }
env -u KITTY_WINDOW_ID PATH="$FAKE_BIN:$PATH" HERDR_LAUNCH_LOG="$TMP_ROOT/launch.log" zsh -fc "source '$REPO_ROOT/wezterm/remote-workflow.zsh'; herdr-testhost() { _ai_configs_herdr_wezterm testhost; }; herdr-testhost"
rg -q '^start --always-new-process -- ssh testhost -t ~/.local/bin/herdr-kitty$' "$TMP_ROOT/launch.log"
PATH="$FAKE_BIN:$PATH" KITTY_WINDOW_ID=1 HERDR_LAUNCH_LOG="$TMP_ROOT/launch.log" zsh -fc "source '$REPO_ROOT/wezterm/remote-workflow.zsh'; herdr-testhost() { _ai_configs_herdr_wezterm testhost; }; herdr-testhost"
rg -q '^ssh testhost -t ~/.local/bin/herdr-kitty$' "$TMP_ROOT/launch.log"

echo 'WezTerm remote workflow tests passed.'
