## REQUIREMENTS
- git
- stow 

## INSTALLATION
```bash
git clone git@github.com:vieko/.dotfiles.git
cd .dotfiles
```
then `stow .` for everything or `stow <folder>` for specific configurations

## REGARDING HYPRLAND
To prevent breaking hyprland when updating other packages, install [hyprland](https://wiki.hyprland.org/Getting-Started/Installation/) manually (from releases or from source) and [hy3](https://github.com/outfoxxed/hy3) using `hyprpm`. Make sure versions match!

### GENERAL
- ADD keybindings for keyboard layout switch
- SET UP Bluetooth properly
- SET UP wifi and vpn properly
- SET UP SSL authentication for github

### DESKTOP
- UPDATE waybar to show ethernet
- UPDATE hyprlock to show feedback

### LAPTOP
- UPDATE waybar to show connected interface
