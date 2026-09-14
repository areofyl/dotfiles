PROMPT='%1~ $ '

# plugins
ZSH_PLUGINS="$HOME/.config/zsh/plugins"
source "$ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# history
HISTFILE="$HOME/.local/state/zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory sharehistory hist_ignore_dups

# completion
autoload -Uz compinit && compinit -d "$HOME/.cache/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# aliases
alias airpods='bluetoothctl connect F0:04:E1:D6:E5:01'
alias restart-bluetooth='sudo modprobe -r hci_bcm4377 && sudo modprobe hci_bcm4377'
alias sudo='sudo -S'
alias print='lp -d Brother_MFC-L3780CDW -o sides=two-sided-long-edge'
alias :q='exit'
corrupt() {
  local C=~/Projects/corrupt/corrupt
  local in="$1" out="$2"
  $C bitplane r ff "$in" /tmp/c1.bmp && \
  $C bitplane g aa /tmp/c1.bmp /tmp/c2.bmp && \
  $C bitplane b 55 /tmp/c2.bmp /tmp/c3.bmp && \
  $C channel brg /tmp/c3.bmp /tmp/c4.bmp && \
  $C bitplane g f0 /tmp/c4.bmp /tmp/c5.bmp && \
  $C bitplane r 0f /tmp/c5.bmp /tmp/c6.bmp && \
  $C convolve emboss /tmp/c6.bmp /tmp/c7.bmp && \
  $C convolve emboss /tmp/c7.bmp /tmp/c8.bmp && \
  $C convolve edge /tmp/c8.bmp "$out"
}
alias ka='killall'
alias vim='nvim'

background() {
  f=$(ls ~/Pictures/wallpapers/ | bemenu -i -c -W 0.4 -l 10 -p 'Wallpaper:' --fn 'FantasqueSansM Nerd Font Mono 15' --tb '#1e1e1e' --tf '#ffffff' --fb '#1e1e1e' --ff '#ffffff' --nb '#1e1e1e' --nf '#ffffff' --hb '#333333' --hf '#ffffff' --sb '#333333' --sf '#ffffff') && [ -n "$f" ] && { pkill swaybg; sleep 0.2; swaybg -i ~/Pictures/wallpapers/"$f" -m fill &disown }
}

wifi() {
  sudo nmcli dev wifi connect "$1" password "$2"
  sudo nmcli con modify "$1" ipv4.dns "1.1.1.1 1.0.0.1" ipv4.ignore-auto-dns yes
}

# env
export NO_AT_BRIDGE=1
export EDITOR=nvim
export VISUAL=nvim
export LANG="en_US.UTF-8"
export GOPATH="$HOME/.local/share/go"
export CARGO_HOME="$HOME/.local/share/cargo"
alias irssi='irssi --home=$HOME/.config/irssi'
export PATH="$HOME/.deno/bin:$HOME/.local/bin:$CARGO_HOME/bin:$HOME/bin:$PATH"
