#!/bin/bash
# 
# The script worked on Contabo's Ubuntu 20.04 in early November 2023.
# Please note that the Steam install path, etc. may have changed, 
# as evidenced by the difference from @cdp1337's code!

# Only allow running as root
if [ "$LOGNAME" != "root" ]; then
  echo "Please run this script as root! (If you ran with 'su', use 'su -' instead)" >&2
  exit 1
fi

# We will use this directory as a working directory for source files that need downloaded.
[ -d /opt/game-resources ] || mkdir -p /opt/game-resources


# Preliminary requirements
dpkg --add-architecture i386
apt update
apt install -y software-properties-common apt-transport-https dirmngr ca-certificates curl wget sudo


# Enable "non-free" repos for Ubuntu 20.04 (for steamcmd)
if grep -Eq '^deb (http|https)://.*ubuntu\.com' /etc/apt/sources.list; then
  # Normal behavior, ubuntu.com is listed in sources.list
  if [ -z "$(grep -E '^deb (http|https)://.*ubuntu\.com.*' /etc/apt/sources.list | grep 'restricted')" ]; then
    # Enable restricted if not already enabled.
    add-apt-repository -y --enable-component=restricted
  fi
  if [ -z "$(grep -E '^deb (http|https)://.*ubuntu\.com.*' /etc/apt/sources.list | grep 'multiverse')" ]; then
    # Enable multiverse if not already enabled.
    add-apt-repository -y --enable-component=multiverse
  fi
else
  # If the machine doesn't have the repos added, we need to add the full list.
  add-apt-repository -y 'deb http://archive.ubuntu.com/ubuntu/ focal restricted universe multiverse'
  add-apt-repository -y 'deb http://security.ubuntu.com/ubuntu/ focal-security restricted universe multiverse'
  add-apt-repository -y 'deb http://archive.ubuntu.com/ubuntu/ focal-updates restricted universe multiverse'
fi


# Install steam repo
curl -s http://repo.steampowered.com/steam/archive/stable/steam.gpg > /usr/share/keyrings/steam.gpg
echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/steam.gpg] http://repo.steampowered.com/steam/ stable steam" > /etc/apt/sources.list.d/steam.list


# Install steam binary and steamcmd
apt update
apt install -y lib32gcc-s1 steamcmd steam-launcher


# Grab Proton from Glorious Eggroll
# https://github.com/GloriousEggroll/proton-ge-custom
PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton8-21/GE-Proton8-21.tar.gz"
PROTON_TGZ="$(basename "$PROTON_URL")"
PROTON_NAME="$(basename "$PROTON_TGZ" ".tar.gz")"
if [ ! -e "/opt/game-resources/$PROTON_TGZ" ]; then
  wget "$PROTON_URL" -O "/opt/game-resources/$PROTON_TGZ"
fi

# Create a "steam" user account
# This will create the account with no password, so if you need to log in with this user,
# run `sudo passwd steam` to set a password.
[ -d /home/steam ] || useradd -m -U steam


# Install ARK Survival Ascended Dedicated
sudo -u steam /usr/games/steamcmd +login anonymous +app_update 2430930 validate +quit


# Determine where Steam is installed
# sometimes it's in ~/Steam, whereas other times it's in ~/.local/share/Steam
# @todo figure out why.... this is annoying.
if [ -e "/home/steam/Steam" ]; then
  STEAMDIR="/home/steam/Steam"
elif [ -e "/home/steam/.local/share/Steam" ]; then
  STEAMDIR="/home/steam/.local/share/Steam"
# When I installed on Ubuntu 20.04, it was here.
elif [ -e "/home/steam/.steam" ]; then
  STEAMDIR="/home/steam/.steam"
else
  echo "Unable to guess where Steam is installed." >&2
  exit 1
fi

if [ -e "$STEAMDIR/steamapps" ]; then
  STEAMAPPSDIR="$STEAMDIR/steamapps"
elif [ -e "$STEAMDIR/SteamApps" ]; then
  STEAMAPPSDIR="$STEAMDIR/SteamApps"
else
  echo "Unable to guess where SteamApps is installed." >&2
  exit 1
fi


# Extract GE Proton into this user's Steam path
[ -d "$STEAMDIR/compatibilitytools.d" ] || sudo -u steam mkdir -p "$STEAMDIR/compatibilitytools.d"
sudo -u steam tar -x -C "$STEAMDIR/compatibilitytools.d/" -f "/opt/game-resources/$PROTON_TGZ"


# Install default prefix into game compatdata path
[ -d "$STEAMAPPSDIR/compatdata" ] || sudo -u steam mkdir -p "$STEAMAPPSDIR/compatdata"
[ -d "$STEAMAPPSDIR/compatdata/2430930" ] || \
  sudo -u steam cp "$STEAMDIR/compatibilitytools.d/$PROTON_NAME/files/share/default_pfx" "$STEAMAPPSDIR/compatdata/2430930" -r

# Install the systemd service file for ARK Survival Ascended Dedicated Server (Island)
cat > /etc/systemd/system/ark-island.service <<EOF
[Unit]
Description=ARK Survival Ascended Dedicated Server (Island)
After=network.target

[Service]
Type=simple
LimitNOFILE=10000
User=steam
Group=steam
WorkingDirectory=$STEAMAPPSDIR/common/ARK Survival Ascended Dedicated Server/ShooterGame/Binaries/Win64
Environment=XDG_RUNTIME_DIR=/run/user/$(id -u)
Environment="STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAMDIR"
Environment="STEAM_COMPAT_DATA_PATH=$STEAMAPPSDIR/compatdata/2430930"
ExecStart=$STEAMDIR/compatibilitytools.d/$PROTON_NAME/proton run ArkAscendedServer.exe TheIsland_WP?listen
Restart=on-failure
RestartSec=20s

[Install]
WantedBy=multi-user.target
EOF

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

XAUDIO_SRC="$SCRIPT_DIR/xaudio2_9.dll"
XAUDIO_DST="$STEAMAPPSDIR/common/ARK Survival Ascended Dedicated Server/ShooterGame/Binaries/Win64/xaudio2_9.dll"

if [ ! -f "$XAUDIO_SRC" ]; then
  echo "xaudio2_9.dll not found next to install script" >&2
  exit 1
fi

sudo -u steam cp "$XAUDIO_SRC" "$XAUDIO_DST"
sudo -u steam chmod 644 "$XAUDIO_DST"

systemctl daemon-reload
systemctl enable ark-island
systemctl start ark-island


# Create some helpful links for the user.
[ -e "/home/steam/island-Game.ini" ] || \
  sudo -u steam ln -s "$STEAMAPPSDIR/common/ARK Survival Ascended Dedicated Server/ShooterGame/Saved/Config/WindowsServer/Game.ini" /home/steam/island-Game.ini

[ -e "/home/steam/island-GameUserSettings.ini" ] || \
  sudo -u steam ln -s "$STEAMAPPSDIR/common/ARK Survival Ascended Dedicated Server/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini" /home/steam/island-GameUserSettings.ini

[ -e "/home/steam/island-ShooterGame.log" ] || \
  sudo -u steam ln -s "$STEAMAPPSDIR/common/ARK Survival Ascended Dedicated Server/ShooterGame/Saved/Logs/ShooterGame.log" /home/steam/island-ShooterGame.log

echo "================================================================================"
echo "If everything went well, ARK Survival Ascended should be installed and starting!"
echo ""
echo "To restart the server: sudo systemctl restart ark-island"
echo "To start the server:   sudo systemctl start ark-island"
echo "To stop the server:    sudo systemctl stop ark-island"
echo ""
echo "Configuration is available in /home/steam/island-Game.ini, /home/steam/island-GameUserSettings.ini"
