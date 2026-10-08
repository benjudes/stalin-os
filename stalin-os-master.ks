# language: Kickstart (KS), target: Fedora Workstation Base, arch: x86_64
# stalin-os-master.ks - Configuração definitiva de Produção para o Stalin OS

lang pt_BR.UTF-8
keyboard br-abnt2
timezone America/Sao_Paulo --utc
network --bootproto=dhcp --device=link --activate
firewall --enabled --service=ssh
selinux --enforcing
services --enabled=NetworkManager,gdm,bluetooth,docker

# Credenciais e Contas Administrativas
rootpw --plaintext stalin_root_secure
user --name=camarada --groups=wheel --plaintext --password=stalin_secure_pass --gecos="Camarada"

# Configuração de Bootloader e Parâmetros de Isolamento de Kernel (IOMMU e Desativação de Mitigações)
bootloader --location=mbr --boot-drive=sda --append="quiet splash amd_iommu=on intel_iommu=on iommu=pt mitigations=off thread_irqs transparent_hugepage=always"
zerombr
clearpart --all --initlabel
autopart --type=btrfs --encrypted --passphrase="stalin_default_secure_pass"

# Repositórios Oficiais e de Terceiros Corrigidos (Fedora 44 Estável)
repo --name=fedora --mirrorlist=https://fedoraproject.org
repo --name=updates --mirrorlist=https://fedoraproject.org
repo --name=rpmfusion-free --mirrorlist=https://rpmfusion.org
repo --name=rpmfusion-nonfree --mirrorlist=https://rpmfusion.org
repo --name=winehq --baseurl=https://winehq.org
repo --name=vscode --baseurl=https://microsoft.com --enabled=1

%packages
@^gnome-desktop-environment
@core
@hardware-support
@multimedia
@sound-and-video

# Produtividade, Escritório e Multimídia
libreoffice
libreoffice-langpack-pt-BR
thunderbird
vlc
gimp
inkscape
obs-studio
code

# Codecs de Mídia Completos (RPM Fusion & FFmpeg)
gstreamer1-plugins-bad-free-extras
gstreamer1-plugins-ugly-free
gstreamer1-plugins-bad-nonfree
gstreamer1-plugins-ugly-nonfree
ffmpeg

# Drivers Proprietários NVIDIA Estáveis
akmod-nvidia
xorg-x11-drv-nvidia-cuda

# Stack Completa de Jogos, Runtimes de 32 e 64 Bits e Emulação
steam
lutris
gamemode
mangohud
vkbasalt
dxvk
vkd3d-proton
wine-staging
winehq-staging
winetricks
cabextract
p7zip
unzip
tar
kernel-devel
kernel-headers
mesa-vulkan-drivers.i686
mesa-vulkan-drivers.x86_64
gnutls.i686
libgphoto2.i686
openal-soft.i686

# Ferramentas de Sistema, Rede e Compilação
git
curl
wget
btop
htop
tmux
zsh
docker
docker-compose
podman
flatpak
gnome-software
gnome-extensions-app
neofetch
gcc
gcc-c++
make
cmake
python3
python3-pip

# Tipografia e Fontes Globais
fontawesome-fonts
dejavu-sans-fonts
google-noto-fonts-common
%end

%post --nochroot
mkdir -p /mnt/sysimage/usr/share/backgrounds/stalin-os/
cp -R /root/stalin-assets/* /mnt/sysimage/usr/share/backgrounds/stalin-os/ 2>/dev/null || :
%end

%post --log=/var/log/stalin-postinstall.log
exec > >(tee -a /var/log/stalin-postinstall.log) 2>&1

echo "[Stalin OS] Iniciando pós-processamento automatizado de sistema..."

# Configuração de DNS Estável (Cloudflare)
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf

# Adicionar repositório Flathub sistêmico corrigido
flatpak remote-add --if-not-exists flathub https://flathub.org

# Função de Retry Linear com Backoff Exponencial para Instalação de Flatpaks
install_flatpak_with_retry() {
    local app_id=$1
    local max_attempts=5
    local attempt=1
    local delay=10

    while [ $attempt -le $max_attempts ]; do
        echo "[Stalin OS] Tentando instalar Flatpak: $app_id (Tentativa $attempt/$max_attempts)..."
        if flatpak install -y flathub "$app_id"; then
            echo "[Stalin OS] Sucesso ao instalar o aplicativo $app_id."
            return 0
        fi
        echo "[Stalin OS] Falha na tentativa $attempt para $app_id. Aguardando ${delay} segundos..."
        sleep $delay
        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done

    echo "[Stalin OS] ERRO: O pacote Flatpak $app_id falhou após $max_attempts tentativas."
    return 1
}

# Array de aplicações essenciais para download assíncrono em background
APPS_FLATPAK=(
    "com.discordapp.Discord"
    "com.spotify.Client"
    "io.heroicgameslauncher.hgl"
    "com.usebottles.bottles"
    "org.mozilla.firefox"
)

for app in "${APPS_FLATPAK[@]}"; do
    install_flatpak_with_retry "$app" &
done

# Aguardar a conclusão de todas as threads paralelas de instalação
wait

# Geração de Identidade Visual em /etc/os-release
cat << 'EOF' > /etc/os-release
NAME="Stalin OS"
ID="stalinos"
ID_LIKE="fedora"
VERSION="1.0 (Red October)"
VERSION_ID="1.0"
VERSION_CODENAME="Red October"
PLATFORM_ID="platform:f44"
PRETTY_NAME="Stalin OS 1.0 (Red October)"
ANSI_COLOR="0;31"
LOGO="fedora-logo-icon"
CPE_NAME="cpe:/o:stalinos:stalin:1.0"
HOME_URL="https://github.com"
BUG_REPORT_URL="https://github.com/issues"
REDHAT_BUGZILLA_PRODUCT="Fedora"
REDHAT_BUGZILLA_PRODUCT_VERSION=44
REDHAT_SUPPORT_PRODUCT="Fedora"
REDHAT_SUPPORT_PRODUCT_VERSION=44
SUPPORT_END=2027-10-07
EOF

# Criação de diretório de configuração do Dconf para o tema escuro padrão
mkdir -p /etc/dconf/db/local.d/
cat << 'EOF' > /etc/dconf/db/local.d/00-stalin-theme
[org/gnome/desktop/interface]
color-scheme='prefer-dark'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/stalin-os/wallpaper.png'
picture-uri-dark='file:///usr/share/backgrounds/stalin-os/wallpaper.png'
EOF
dconf update

# Injeção de Tuning de Sistema e Memória Virtual
cat << 'EOF' > /etc/sysctl.d/99-stalin-gaming.conf
vm.max_map_count = 2147483642
vm.swappiness = 10
vm.vfs_cache_pressure = 50
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

# Configuração de Limites de Descritores de Arquivos Abertos
cat << 'EOF' > /etc/security/limits.d/99-stalin-limits.conf
* soft nofile 524288
* hard nofile 524288
root soft nofile 524288
root hard nofile 524288
EOF

# Configuração do GameMode do Feral Interactive
mkdir -p /etc/gamemode.ini
cat << 'EOF' > /etc/gamemode.ini
[general]
desiredgov=performance
renice=10
ioprio=0
supervisor=auto

[filter]
whitelist=steam,lutris,heroic,gamescope
EOF

# Habilitação definitiva de Daemons do Systemd
systemctl enable docker
systemctl enable bluetooth
systemctl enable gdm
systemctl enable NetworkManager

echo "[Stalin OS] Script de pós-instalação concluído com êxito."
%end
