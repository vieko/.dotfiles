## REQUIREMENTS

- git
- stow

## INSTALLATION

```bash
git clone git@github.com:vieko/.dotfiles.git
cd .dotfiles
```

Then `stow .` for everything or `stow <folder>` for specific configurations.

For packages linking outside of the home directory, use: `stow -t / <folder>`. You may need to run this as root.

## REGARDING HYPRLAND

To prevent breaking hyprland when updating other packages, install [hyprland](https://wiki.hyprland.org/Getting-Started/Installation/) manually (from releases or from source) and [hy3](https://github.com/outfoxxed/hy3) using `hyprpm`. Make sure versions match!

## MY KEYBOARD LAYOUTS

![Kinesis](https://github.com/vieko/.dotfiles/blob/main/assets/Screenshots/kinesis-layout.png)
![Voyager](https://github.com/vieko/.dotfiles/blob/main/assets/Screenshots/voyager-layout.png)

### GENERAL

- ADD keybindings for keyboard layout switch
- SET UP Bluetooth properly
- SET UP wifi and vpn properly
- SHOW when on resize mode
- ADD hyprpicker
- CONFIG NextDNS

### DESKTOP

- UPDATE waybar to show ethernet

### LAPTOP

- UPDATE waybar to show connected interface
- INSTALL Docker
