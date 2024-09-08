function open_new_terminal
  set cwd (pwd)
  kitty --working-directory="$cwd"
end
