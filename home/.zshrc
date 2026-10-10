# Lumen terminal: quick navigation, useful defaults, no framework overhead.
HISTFILE="$HOME/.cache/zsh/history"
HISTSIZE=50000
SAVEHIST=50000
setopt AUTO_CD AUTO_PUSHD SHARE_HISTORY HIST_IGNORE_DUPS
mkdir -p "${HISTFILE:h}"
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select

export EDITOR=nvim
export VISUAL=nvim
export PAGER='less -R'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export PATH="$HOME/.local/bin:$HOME/.config/lumen/bin:$PATH"

eval "$(zoxide init zsh)"
alias cd='z'
alias cdi='zi'
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never --style=plain'
alias c='clear'
alias v='nvim'
alias g='lazygit'
alias d='lazydocker'
alias update='lumen update'

for spaceship in /usr/share/zsh-theme/spaceship.zsh /usr/share/zsh/plugins/spaceship/spaceship.zsh; do
  [[ -r "$spaceship" ]] && source "$spaceship" && break
done
[[ -n "${SPACESHIP_VERSION:-}" ]] || eval "$(starship init zsh)"
