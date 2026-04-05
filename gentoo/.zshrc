PROMPT='%1~ $ '

# plugins (standalone, no framework)
ZSH_PLUGINS="$HOME/.zsh/plugins"
source "$ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# fzf
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
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
alias n='nvim'
alias airpods='bluetoothctl connect F0:04:E1:D6:E5:01'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'

alias sudo='sudo -S'

# full system update
update() {
  if [ "$1" = "--check" ]; then
    echo "\033[0;36m:: checking for updates\033[0m"
    sudo emerge --update --deep --newuse --pretend @world
    return
  fi
  echo "\033[0;36m:: syncing repos\033[0m"
  sudo emerge --sync
  echo "\033[0;36m:: updating world\033[0m"
  sudo emerge --update --deep --newuse @world
  echo "\033[0;36m:: removing orphans\033[0m"
  sudo emerge --depclean
  echo "\033[0;36m:: rebuilding broken packages\033[0m"
  sudo revdep-rebuild
  echo "\033[0;36m:: cleaning distfiles\033[0m"
  sudo eclean-dist --deep
  echo "\033[0;32m:: update complete\033[0m"
}

# suppress accessibility bus (no screen reader needed)
export NO_AT_BRIDGE=1

wifi() {
  sudo nmcli dev wifi connect "$1" password "$2"
  sudo nmcli con modify "$1" ipv4.dns "1.1.1.1 1.0.0.1" ipv4.ignore-auto-dns yes
}

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/bin:$PATH"
