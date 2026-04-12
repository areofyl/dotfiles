PROMPT='%1~ $ '

# plugins (standalone, no framework)
ZSH_PLUGINS="$HOME/.zsh/plugins"
source "$ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# fzf
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
[ -f ~/.config/nimbus/fzf.sh ] && source ~/.config/nimbus/fzf.sh
source <(fzf --zsh)

# history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory sharehistory hist_ignore_dups

# completion (replaces omz's completion system)
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# aliases
alias fnvim='nvim $(fd --type f --hidden --exclude .git | fzf -m --preview="bat --color=always {}")'
alias airpods='bluetoothctl connect F0:04:E1:D6:E5:01'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'

alias sudo='sudo -S'
alias restart-bluetooth='sudo modprobe -r hci_bcm4377 && sudo modprobe hci_bcm4377'

# suppress accessibility bus (no screen reader needed)
export NO_AT_BRIDGE=1

wifi() {
  sudo nmcli dev wifi connect "$1" password "$2"
  sudo nmcli con modify "$1" ipv4.dns "1.1.1.1 1.0.0.1" ipv4.ignore-auto-dns yes
}

export XCURSOR_THEME=macOS-Tahoe
export XCURSOR_SIZE=24
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/bin:$PATH"
