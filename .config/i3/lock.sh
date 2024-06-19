#!/bin/bash

hostname=$(hostname)
rosewater='#f5e0dc'
flamingo='#f2cdcd'
pink='#f5c2e7'
mauve='#cba6f7'
red='#f38ba8'
maroon='#eba0ac'
peach='#fab387'
yellow='#f9e2af'
green='#a7e3a1'
teal='#94e2d5'
sky='#89dceb'
sapphire='#74c7ec'
blue='#89b4fa'
lavender='#b4befe'
text='#cdd6f4'
subtext1='#bac2de'
subtext0='#a6adc8'
overlay2='#9399b2'
overlay1='#7f849c'
overlay0='#6c7086'
surface2='#585b70'
surface1='#45475a'
surface0='#313244'
base='#1e1e2e'
mantle='#181825'
crust='#11111b'

i3lock \
--color $base \
--bar-indicator \
--bar-pos y+h \
--bar-direction 1 \
--bar-max-height 5 \
--bar-base-width 5 \
--bar-color $base \
--keyhl-color $lavender \
--bar-periodic-step 5 \
--bar-step 5 \
--redraw-thread \
\
--clock \
--force-clock \
--time-pos x+10:y+h-15 \
--time-color $mauve \
--time-size 32 \
--time-align 1 \
--date-pos tx:ty+15 \
--date-color $mauve \
--date-size 20 \
--date-align 1 \
--date-str "" \
--ringver-color $lavender \
--ringwrong-color $maroon \
--status-pos x+5:y+h-16 \
--greeter-size 48 \
--greeter-color $mauve \
--greeter-text "󰡛" \
--verif-size 16 \
--verif-color $lavender \
--verif-text "" \
--wrong-size 16 \
--wrong-color $maroon \
--wrong-text "" \
--greeter-align 1 \
--verif-align 1 \
--wrong-align 1 \
--modif-pos -5:-5 \
\
--verif-font="Symbols Nerd Font Mono" \
--wrong-font="Symbols Nerd Font Mono" \
--layout-font="MonoLisaCustom-Medium" \
--greeter-font="Symbols Nerd Font Mono" \
--time-font="MonoLisaCustom-Medium" \
--date-font="MonoLisaCustom-Medium"

