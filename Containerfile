FROM quay.io/fedora/fedora-bootc:44
RUN dnf update -y && dnf install -y @gnome-desktop-environment @hardware-support @multimedia @sound-and-video kernel kernel-core kernel-modules steam lutris gamemode mangohud akmod-nvidia xorg-x11-drv-nvidia-cuda libreoffice vlc gimp inkscape obs-studio code git curl wget btop htop tmux zsh docker podman flatpak && dnf clean all
RUN flatpak remote-add --if-not-exists flathub https://flathub.org
COPY sysctl/99-stalin-gaming.conf /etc/sysctl.d/99-stalin-gaming.conf
COPY limits/99-stalin-limits.conf /etc/security/limits.d/99-stalin-limits.conf
RUN systemctl enable gdm docker bluetooth NetworkManager
