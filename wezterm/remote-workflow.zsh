# Managed by ai-configs/wezterm/install.sh.

_ai_configs_herdr_wezterm() {
  local host="$1"
  local launcher='~/.local/bin/herdr-kitty'

  # Preserve Kitty's direct kitten SSH experience when the command is run from
  # Kitty. Everywhere else, open the requested Herdr host in a WezTerm window.
  if [[ -n ${KITTY_WINDOW_ID:-} ]] && (( $+commands[kitten] )); then
    command kitten ssh "$host" -t "$launcher"
  elif (( $+commands[wezterm] )); then
    command wezterm start --always-new-process -- ssh "$host" -t "$launcher"
  else
    print -u2 'herdr launcher: neither wezterm nor kitten is installed'
    return 127
  fi
}

# The Kitty workflow may have defined these names as aliases earlier in .zshrc.
# Remove them before declaring functions because zsh expands aliases while parsing
# the name() function syntax.
unalias herdr-mbp herdr-dever herdr-thump herdr-mbp14 2>/dev/null

# No remote hosts configured in this fork yet. Upstream defined herdr-<host>
# helpers for the original author's machines; add your own here, e.g.:
#   herdr-myhost() { _ai_configs_herdr_wezterm myhost; }
# herdr-mbp() { _ai_configs_herdr_wezterm mbp; }
# herdr-dever() { _ai_configs_herdr_wezterm dever; }
# herdr-thump() { _ai_configs_herdr_wezterm thump; }

wezterm-remote-help() {
  print -P '%F{cyan}WezTerm remote workflow%f'
  print -P '  %F{green}herdr-<host>%f                            open Herdr in a new WezTerm window (define hosts above)'
  print -P '  %F{yellow}Cmd+Shift+1/2/3%f                         launch-menu remote entries (configure in remote-workflow.lua)'
  print -P '  %F{yellow}Cmd+Shift+V%f                             upload a clipboard image and paste its remote path'
}
