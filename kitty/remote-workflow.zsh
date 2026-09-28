# Managed by ai-configs/kitty/install.sh.
alias kssh='kitten ssh'
# No remote hosts configured in this fork yet. Upstream aliased the original
# author's machines with his username and remote home paths; replace with your
# own hosts/paths when you set up remote machines, e.g.:
#   alias herdr-myhost='kitten ssh myhost -t /home/myuser/.local/bin/herdr-kitty'
# alias herdr-mbp='kitten ssh mbp -t /Users/anichols/.local/bin/herdr-kitty'
# alias herdr-dever='kitten ssh dever -t /home/anichols/.local/bin/herdr-kitty'

kitty-remote-help() {
  print -P '%F{cyan}Kitty remote workflow%f'
  print -P '  %F{green}kssh <host>%f                        kitten ssh to a host'
  print -P '  %F{green}mosh <host>%f                         mosh to a host, then run herdr remotely'
  print -P '  (upstream also shipped herdr-mbp / herdr-dever aliases; re-add yours in kitty/remote-workflow.zsh)'
  print -P '  %F{yellow}Cmd+Shift+V%f              upload a clipboard image and paste its path'
  print -P '  Run %F{green}kitty-remote-help%f to show this reminder again.\n'
}

if [[ -o interactive && -n ${KITTY_WINDOW_ID:-} && -z ${SSH_CONNECTION:-} ]]; then
  kitty-remote-help
fi
