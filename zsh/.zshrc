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

# env
export NO_AT_BRIDGE=1
export EDITOR=nvim VISUAL=nvim
export LANG="en_US.UTF-8"
export GOPATH="$HOME/.local/share/go"
export CARGO_HOME="$HOME/.local/share/cargo"
export DENO_DIR="$HOME/.local/share/deno"
export PATH="$DENO_DIR/bin:$HOME/.local/bin:$CARGO_HOME/bin:$PATH"

# aliases
alias airpods='bluetoothctl connect F0:04:E1:D6:E5:01'
alias restart-bluetooth='sudo modprobe -r hci_bcm4377 && sudo modprobe hci_bcm4377'
alias sudo='sudo -S'
alias print='lp -d Brother_MFC-L3780CDW -o sides=two-sided-long-edge'
alias :q='exit'
alias ka='killall'
alias irssi='irssi --home=$HOME/.config/irssi'
