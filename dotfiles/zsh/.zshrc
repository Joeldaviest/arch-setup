[[ -o interactive ]] || return

export PATH="$HOME/.local/bin:$PATH"
export ZSH="/usr/share/oh-my-zsh"
ZSH_THEME="awesomepanda"
plugins=(git docker docker-compose fzf extract)

source "$ZSH/oh-my-zsh.sh"
source "$HOME/.config/zsh/envs"
source "$HOME/.config/zsh/aliases"
source "$HOME/.config/zsh/functions"
source "$HOME/.config/zsh/init"
