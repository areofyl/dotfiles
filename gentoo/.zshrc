PROMPT='%1~ $ '

# plugins (standalone, no framework)
ZSH_PLUGINS="$HOME/.zsh/plugins"
source "$ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory sharehistory hist_ignore_dups

# completion (replaces omz's completion system)
autoload -Uz compinit && compinit -d "$HOME/.cache/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# aliases 
alias airpods='bluetoothctl connect F0:04:E1:D6:E5:01'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'

alias sudo='sudo -S'
alias restart-bluetooth='sudo modprobe -r hci_bcm4377 && sudo modprobe hci_bcm4377'
alias print='lp -d Canon_MF260_Series_UFRII_LT -o sides=two-sided-long-edge' 


# suppress accessibility bus (no screen reader needed)
export NO_AT_BRIDGE=1

wifi() {
  sudo nmcli dev wifi connect "$1" password "$2"
  sudo nmcli con modify "$1" ipv4.dns "1.1.1.1 1.0.0.1" ipv4.ignore-auto-dns yes
}

export LANG="en_US.UTF-8"
export XCURSOR_THEME=macOS-Tahoe
export XCURSOR_SIZE=24
export GOPATH="$HOME/.local/share/go"
export CARGO_HOME="$HOME/.local/share/cargo"
export PATH="$HOME/.local/bin:$CARGO_HOME/bin:$HOME/bin:$PATH"

if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        sudo mkdir -p "$XDG_RUNTIME_DIR"
        sudo chmod 0700 "$XDG_RUNTIME_DIR"
        sudo chown "$(id -u):$(id -g)" "$XDG_RUNTIME_DIR"
    fi
fi
