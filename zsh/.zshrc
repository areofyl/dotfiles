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
alias print='lp -d Canon_MF260_Series_UFRII_LT -o sides=two-sided-long-edge' 
alias :q='exit'
alias ka='killall'

# suppress accessibility bus (no screen reader needed)
export NO_AT_BRIDGE=1

wifi() {
  sudo nmcli dev wifi connect "$1" password "$2"
  sudo nmcli con modify "$1" ipv4.dns "1.1.1.1 1.0.0.1" ipv4.ignore-auto-dns yes
}

pdf() {
  f=$(find ~/Documents -name '*.pdf' | sed "s|$HOME/Documents/||" | fzf)
  [ -n "$f" ] && setsid zathura ~/Documents/"$f" &>/dev/null && kill $PPID
}

# nnn
export NNN_OPTS="dHU"
export NNN_COLORS="#c4ccd4"
export NNN_FCOLORS="c1e20402006033f7c6d6abc4"
export NNN_TRASH=1
export NNN_FIFO=/tmp/nnn.fifo
export NNN_PLUG='p:preview-tui'
export NNN_OPENER="$HOME/.config/nnn/opener"
alias n='nnn -P p'

export EDITOR=nvim
export VISUAL=nvim
export LANG="en_US.UTF-8"
export XCURSOR_THEME=macOS-Tahoe
export XCURSOR_SIZE=24
export GOPATH="$HOME/.local/share/go"
export CARGO_HOME="$HOME/.local/share/cargo"
export PATH="$HOME/.local/bin:$CARGO_HOME/bin:$HOME/bin:$PATH"
export W3M_DIR="$HOME/.config/w3m"
export IRSSI_HOME="$HOME/.config/irssi"
export VIMINFOFILE="$HOME/.local/state/viminfo"

. "/home/aarav/.deno/env"
