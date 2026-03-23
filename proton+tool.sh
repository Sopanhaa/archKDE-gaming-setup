sudo pacman -S --noconfirm \
    steam lutris mangohud gamemode \
    wine winetricks vulkan-tools

# Flatpak
sudo pacman -S flatpak --noconfirm
flatpak install -y flathub \
    com.heroicgameslauncher.hgl \
    net.davidotek.pupgui2 \
    org.prismlauncher.PrismLauncher
