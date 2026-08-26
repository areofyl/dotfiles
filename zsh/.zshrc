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
alias vim='nvim'

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
export PATH="$HOME/.deno/bin:$HOME/.local/bin:$CARGO_HOME/bin:$HOME/bin:$PATH"
