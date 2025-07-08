#export GTK_USE_PORTAL=1
#export XDG_CURRENT_DESKTOP=Hyprland
export TERM=xterm-256color

autoload -U select-word-style
select-word-style bash

bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[[3~" delete-char
bindkey "^[[3;5~" kill-word
bindkey "^H" backward-kill-word
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

PATH=$USER/.local/sh:$USER/.local/bin:$PATH
