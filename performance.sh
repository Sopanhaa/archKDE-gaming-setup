# CPU governor
sudo pacman -S cpupower --noconfirm
sudo systemctl enable --now cpupower

echo 'governor="performance"' | sudo tee /etc/default/cpupower

# sysctl tuning
sudo cp configs/sysctl.conf /etc/sysctl.d/99-gaming.conf

# Enable TRIM (SSD)
sudo systemctl enable fstrim.timer

# Gamemode config
mkdir -p ~/.config
cp configs/gamemode.ini ~/.config/
