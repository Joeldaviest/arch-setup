[[ -o interactive ]] || return

export PATH="$HOME/.local/bin:$PATH"
export ZSH="/usr/share/oh-my-zsh"
ZSH_THEME="awesomepanda"
plugins=(git docker docker-compose)

source "$ZSH/oh-my-zsh.sh"
source "$HOME/.config/arch-setup/zsh/envs"
source "$HOME/.config/arch-setup/zsh/aliases"
source "$HOME/.config/arch-setup/zsh/functions"
source "$HOME/.config/arch-setup/zsh/init"

