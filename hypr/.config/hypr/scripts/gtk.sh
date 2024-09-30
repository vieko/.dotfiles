#!/bin/bash

config="$HOME/.config/gtk-3.0/settings.ini"
schema="org.gnome.desktop.interface"

if [ ! -f "$config" ]; then
    echo "ERROR: GTK3 config file not found at $config"
    exit 1
fi

# === function to read settings from config file
read_setting() {
    grep -i "$1" "$config" | sed 's/.*\s*=\s*//'
}

# === read settings
gtk_theme=$(read_setting "gtk-theme-name")
icon_theme=$(read_setting "gtk-icon-theme-name")
cursor_theme=$(read_setting "gtk-cursor-theme-name")
cursor_size=$(read_setting "gtk-cursor-theme-size")
font_name=$(read_setting "gtk-font-name")
text_scaling_factor=$(read_setting "gtk-text-scaling-factor")
monospace_font_name=$(read_setting "gtk-monospace-font-name")
document_font_name=$(read_setting "gtk-document-font-name")


# === apply settings
apply_setting() {
    if [ -n "$2" ]; then
        gsettings set "$schema" "$1" "$2"
        echo "Set $1 to $2"
    else
        echo "WARNING: $1 not found in config"
    fi
}

apply_setting "gtk-theme" "$gtk_theme"
apply_setting "icon-theme" "$icon_theme"
apply_setting "cursor-theme" "$cursor_theme"
apply_setting "cursor-size" "$cursor_size"
apply_setting "font-name" "$font_name"
apply_setting "text-scaling-factor" "$text_scaling_factor"
apply_setting "monospace-font-name" "$monospace_font_name"
apply_setting "document-font-name" "$document_font_name"

echo "GTK settings applied successfully"
