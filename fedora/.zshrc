# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agnosterzak"

plugins=( 
    git
    dnf
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Boxed bronze prompt with Tux and arrow end
#PROMPT=$'%K{#1C292D}%F{#D4A574} %1~ %k%F{#1C292D}\ue0b0%f '
PROMPT=' %F{#D4A574}%1~%f '

# check the dnf plugins commands here
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/dnf
alias fnvim='nvim $(fzf -m --preview="bat --color=always {}")'

# Display Pokemon-colorscripts
# Project page: https://gitlab.com/phoneybadger/pokemon-colorscripts#on-other-distros-and-macos
#pokemon-colorscripts --no-title -s -r #without fastfetch
#pokemon-colorscripts --no-title -s -r | fastfetch -c $HOME/.config/fastfetch/config-pokemon.jsonc --logo-type file-raw --logo-height 10 --logo-width 5 --logo -

# Run animated fastfetch on startup (disabled)
#if [[ -o interactive ]]; then
#    $HOME/.config/fastfetch/asahi-animated.sh 0.05
#fi

# Set-up FZF key bindings (CTRL R for fuzzy history finder)
source <(fzf --zsh)

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

# Set-up icons for files/directories in terminal using lsd
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"
# Cursor switching functions
troll_cursor() {
  hyprctl setcursor troll-cursor 48
  gsettings set org.gnome.desktop.interface cursor-theme 'troll-cursor'
  gsettings set org.gnome.desktop.interface cursor-size 48
  echo "Switched to troll cursor 🧌"
}

default_cursor() {
  hyprctl setcursor Bibata-Modern-Ice 24
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'
  gsettings set org.gnome.desktop.interface cursor-size 24
  echo "Switched to default cursor"
}
export PATH="$HOME/bin:$PATH"

# fnm
FNM_PATH="/home/aarav/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi
