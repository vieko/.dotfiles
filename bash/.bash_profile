# source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# source the user's bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

# [ "$(tty)" = "/dev/tty1" ] && exec sway
