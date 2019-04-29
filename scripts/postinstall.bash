#!/bin.bash

# Set default value
read -e -p 'wired only:' -i 0 wired_only
if [[ $wired_only = 0 ]]; then
  read -e -p 'wired network interface:' -i enp3s0 network_interface['wired']
  read -e --p 'wireless network interface:' -i wlp5s0 network_interface['wireless']
fi
read -e -p 'keykayout:' -i jp keylayout

# Configure the system
## Network
### Netwrk configuration
if [[ $wired_only = 0 ]]; then
  sudo sed -i -e "s/eth0/${network_interface["wired"]}/" /etc/ifplugd/ifplugd.conf
  sudo cp /etc/netctl/examples/ethernet-dhcp /etc/netctl/${network_interface["wired"]}-dhcp
  sudo sed -i -e "s/eth0/${network_interface["wired"]}/" /etc/netctl/${network_interface["wired"]}-dhcp
  sudo systemctl enable --now netctl-ifplugd@${network_interface["wired"]}.service

  sudo cp /etc/netctl/examples/wireless-wpa /etc/netctl/${network_interface["wireless"]}-dhcp
  sudo sed -i -e "s/wlan0/${network_interface["wireless"]}/" /etc/netctl/${network_interface["wireless"]}-dhcp
  sudo systemctl enable --now netctl-auto@${network_interface["wireless"]}
fi
sudo pacman -S --noconfirm nmap traceroute bind-tools whois

### Clock synchronization
sudo sed -i -e "s/#NTP=/NTP=`echo {0..3}.jp.pool.ntp.org`/" /etc/systemd/timesyncd.conf
sudo sed -i -e '/#FallbackNTP/s/#//' /etc/systemd/timesyncd.conf
sudo timedatectl set-ntp true
sudo timedatectl status

### Firewall
sudo pacman -S --noconfirm ufw
sudo systemctl enable --now ufw
sudo ufw default deny
sudo ufw enable

## System administration
### Service management
sudo sed -i -e '/#DefaultTimeoutStopSec/s/90s/5s/' /etc/systemd/system.conf
sudo sed -i -e '/#DefaultTimeoutStopSec/#//' /etc/systemd/system.conf
sudo sed -i -e 's/#SystemMaxUse=/SystemMaxUse=5M/' /etc/systemd/journald.conf

## Package management
### pacman
sudo sed -i -e '/Color/s/#//' /etc/pacman.conf
sudo pacman -Fy

### makepkg
sudo sed -i -e '/#MAKEFLAGS="-j2"/s/#//' /etc/makepkg.conf
sudo sed -i -e '/COMPRESSXZ/s/xz -c/xz -T 0 -c/' /etc/makepkg.conf

### pkgfile
sudo pacman -S --noconfirm pkgfile
sudo systemctl start pkgfile-update
sudo systemctl enable --now pkgfile-update.timer

### AUR helper
curl -L -o '/tmp/#1' \
  https://aur.archlinux.org/cgit/aur.git/snapshot/{yay.tar.gz}
tar xzvf /tmp/yay.tar.gz -C /tmp/
cd /tmp/yay
makepkg -si --noconfirm
cd -

## Programming languages
### Go
sudo pacman -S --noconfirm go go-tools
export GOPATH="$HOME/.local"

## Graphical User Interface
### Display server
sudo pacman -S --noconfirm xorg-server xorg-xinit xorg-xwininfo \
  xorg-xbacklight xorg-xinput xorg-xrandr

### Display driver
sudo pacman -S --noconfirm xf86-video-intel

### Window Manager
sudo pacman -S --noconfirm i3-gaps dmenu xorg-xsetroot \
  compton unclutter libnotify dunst xdg-user-dirs xcape
yay -S --noconfirm j4-dmenu-desktop polybar-git

### Screen locker
sudo pacman -S --noconfirm xautolock xss-lock imagemagick
yay -S --noconfirm i3lock-color-git
mkdir -p /.local/share/i3/
cat <<EOF > ~/.local/share/i3/lockscreen.svg
<svg viewBox="0 0 1920 1080" xmlns="http://www.w3.org/2000/svg">
  <rect width="100%" height="100%"/>
  <circle cx="960" cy="540" r="200" fill="none" storke="#2196f3" stroke-width="10"/>
</svg>
EOF
convert ~/.local/share/i3/lockscreen.svg ~/.local/share/i3/lockscreen.png

### Power management
### ACPI events
sudo pacman -S --noconfirm acpi tlp tp_smapi acpi_call
sudo sed -i -e 's/#HandlePowerKey=poweroff/HandlePowerKey=suspend/' \
  /etc/systemd/logind.conf
sudo sed -i -e 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' \
  /etc/systemd/logind.conf

sudo systemctl restart systemd-logind

sudo curl -o '/etc/udev/rules.d/#1' \
  https://githubusercontent.com/mryyomutga.archlinux-installer/master/etc/udev/{99-lowbat.rules}

## Multimedia
### Sound
sudo pacman -S --noconfirm alsa-utils sound-theme-freedesktop pulseaudio pamixer

### Solve cracking sound through speakers problem
sudo bash -c \
  "echo 'options snd_hda_intel power_save=0' > /etc/modprobe.d/sound.conf"

### Audio player
yay -S --noconfirm spotify

### Video player
sudo pacman -S --noconfirm mpv

### PDF viewer
sudo pacman -S --noconfirm zathura zathura-pdf-mupdf

### Image viewer
sudo pacman -S --noconfirm feh imv

### Screenshot
sudo pacman -S --noconfirm slop maim scrot

### Screencast
sudo pacman -S --noconfirm ffmpeg

## Input devices
### Keyboard layout
declare keymodel
keymodel=jp106
sudo localectl set-x11-keymap "$keylayout" "$keymodel" \
  ctrl:nocaps,terminate:ctrl_alt_bksp

sudo pacman -S --noconfirm bluez bluez-utils
sudo systemctl enable --now bluetooth
sudo sed -i -e 's/^#AutoEnable=false$/AutoEnable=true/' /etc/bluetooth/main.conf

## Appearance
### Fonts
sudo pacman -S --noconfirm noto-fonts-cjk ttf-hack awesome-terminal-fonts \
  ttf-material-icons noto-fonts

### GTK+ theme
sudo pacman -S --noconfirm arc-gtk-theme

## Develper tools
sudo pacman -S --noconfirm asciidoctor asciinema hub jq openssh rigrep tmux fzf \
  ctags colordiff tree optipng jpegoptim svgcleaner httpie fd libwebp exa \
  shellcheck bat avrdude keybase ghi vint

yay -S --noconfirm ghq direnv docker-credential-secretservice \
  slack-desktop

go get -u github.com/stamblerre/gocode
go get -u github.com/x/tools/cmd/goimports
go get -u golang.org/x/lint/golint
go get -u golang.org/x/tools/cmd/gotypes
go get -u golang.org/x/tools/cmd/gopls

# for avrdude
sudo gpasswd -a $USER uucp
sudo gpasswd -a $USER lock
sudo gpasswd -a $USER dialog
sudo pacman -S --noconfirm docker docker-compose
sudo systemctl enable --now docker
sudo gpasswd -a $USER docker

## Utilities
sudo pacman -S --noconfirm \
  dosfstools gptfdisk \
  unzip xautomation xsel zip encfs neofetch translate-shell \
  aria2 pigz pixz pbzip2 trash-cli
yay -S --noconfirm arch-wiki-man
go get -u github.com/pocke/xrandr-mirror
goget -u github.com/mattn/twty

### Terminal emulator
sudo pacman -S --noconfirm termite
yay -S --noconfirm alacritty

### Text Editor
sudo pacman -S --noconfirm neovim python2-neovim python-neovim

### File Manager
sudo pacman -S --noconfirm ranger w3m highlight atool mediainfo poppler


