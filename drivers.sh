GPU=$(lspci | grep -E "VGA|3D")

if echo "$GPU" | grep -i nvidia; then
    sudo pacman -S --noconfirm nvidia nvidia-utils nvidia-settings

    echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf

elif echo "$GPU" | grep -i amd; then
    sudo pacman -S --noconfirm mesa vulkan-radeon lib32-vulkan-radeon

elif echo "$GPU" | grep -i intel; then
    sudo pacman -S --noconfirm mesa vulkan-intel lib32-vulkan-intel
fi
