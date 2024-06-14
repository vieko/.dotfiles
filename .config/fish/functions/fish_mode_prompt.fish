function fish_mode_prompt
  switch $fish_bind_mode
    case default
      set_color --bold $fish_color_gray
      echo 'N '
    case insert
      set_color --bold $fish_color_gray 
      echo 'I '
    case replace_one
      set_color --bold $fish_color_gray
      echo 'R ' 
    case visual
      set_color --bold $fish_color_gray
      echo 'V '
    case '*'
      set_color --bold $fish_color_gray 
      echo '? '
  end
  set_color $fish_color_normal
end

