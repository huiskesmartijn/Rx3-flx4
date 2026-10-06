#!/bin/bash
# One-shot setup on a freshly flashed Raspberry Pi OS: everything INSTALL.md describes, in order, in one command.
# Run as your normal user from the directory this file lives in (it asks for sudo). Safe to re-run: steps that are
# already done are skipped, and a re-run after "git pull" rebuilds and reinstalls the host side.
#
#   ./setup.sh                             packages, firmware, chroot, host install, enable at boot
#   ./setup.sh --display waveshare-10.1-dsi  ... and add that panel's lines to /boot/firmware/config.txt
#   ./setup.sh --rebuild                   rebuild the chroot even if it exists (resets the player's own settings)
#   ./setup.sh --reboot                    reboot at the end without asking
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")"
. ./rx3-env.sh
ok(){ printf '  \033[32mok\033[0m   %s\n' "$1"; }
step(){ printf '\n\033[1m== %s\033[0m\n' "$1"; }
die(){ printf '\n\033[31mSetup stopped:\033[0m %s\n' "$1" >&2; exit 1; }

DISPLAY_PANEL=""; REBUILD=0; REBOOT=ask
while [ $# -gt 0 ]; do
  case "$1" in
    --display) DISPLAY_PANEL="${2:-}"; shift;;
    --rebuild) REBUILD=1;;
    --reboot)  REBOOT=yes;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "unknown option $1 (see ./setup.sh --help)";;
  esac; shift
done
case "$DISPLAY_PANEL" in ''|waveshare-10.1-dsi) ;; *) die "unknown display '$DISPLAY_PANEL' (known: waveshare-10.1-dsi)";; esac

[ "$(id -u)" = 0 ] && die "run this as your normal user, not with sudo: the chroot is built in that user's home."
[ "$(stat -c %U .)" = "$(id -un)" ] || die "$(pwd) belongs to $(stat -c %U .), not $(id -un). Fix with: sudo chown -R \$(id -un):\$(id -gn) \"$(pwd)\""
sudo -v || die "this needs sudo."
chmod +x ./*.sh ./*.py
REBOOT_NEEDED=0

# --- 1. display panel (config.txt) ----------------------------------------------------------------------------
if [ -n "$DISPLAY_PANEL" ]; then
  step "display: $DISPLAY_PANEL"
  CONFIG=${RX3_BOOT_CONFIG:-/boot/firmware/config.txt}; [ -f "$CONFIG" ] || CONFIG=/boot/config.txt
  if grep -q '^dtoverlay=vc4-kms-dsi-waveshare-panel' "$CONFIG"; then
    ok "$CONFIG already has a Waveshare panel line, left as it is"
  else
    # Waveshare 10.1inch DSI LCD (C) on the Pi 5's DSI0 connector: the [pi5] block from the SD card Waveshare ships,
    # which matches the panel's printed manual (ov5647 is the camera module some kits include).
    [ -f "$CONFIG.rx3-backup" ] || sudo cp "$CONFIG" "$CONFIG.rx3-backup"
    printf '\n# Waveshare 10.1inch DSI LCD (C), ribbon in the connector marked 0 (added by rx3 setup.sh)\n[pi5]\ndtoverlay=nospi10\ndtoverlay=ov5647\ndtoverlay=vc4-kms-dsi-waveshare-panel,10_1_inch,dsi0\n[all]\n' \
      | sudo tee -a "$CONFIG" >/dev/null || die "could not write $CONFIG"
    ok "added the panel to $CONFIG (backup: $CONFIG.rx3-backup); takes effect after the reboot"
    REBOOT_NEEDED=1
  fi
fi

# --- 2. packages ------------------------------------------------------------------------------------------------
step "packages"
./install.sh deps || die "installing packages failed: run ./install.sh deps to see why."
ok "Debian packages installed"

# --- 3. firmware (downloaded from AlphaTheta/Pioneer and hash-checked; kept, so a re-run does not fetch again) ----
step "firmware"
if [ -f extracted/player/pdj/rbp ] && [ -f runtime-symlinks.json ] && [ -d extracted/runtime-files ]; then
  ok "already recovered and extracted"
else
  python3 recover-firmware.py || die "recover-firmware.py failed (network, or a download did not match its hash)."
  python3 extract_cramfs.py | tail -1 || die "extract_cramfs.py failed."
  [ -f runtime-symlinks.json ] || die "extract_cramfs.py did not finish: run it again."
  ok "recovered and extracted"
fi

# --- 4. chroot --------------------------------------------------------------------------------------------------
# build-rootfs.sh wipes and recreates the chroot, its /dev included, so the player must be stopped and every bind
# mount into the chroot gone first (rx3-stop.sh unmounts them); deleting through a live bind of /dev/snd would
# delete the host's own device nodes.
step "player environment (chroot)"
if systemctl is-active -q rx3; then sudo systemctl stop rx3 && ok "stopped the running player"; fi
if [ -d "$RX3_ROOT/root/pdj" ] && [ $REBUILD = 0 ]; then
  ok "already built at $RX3_ROOT (--rebuild to start it over, which resets the player's own settings)"
else
  findmnt -rn -o TARGET | grep -q "^$RX3_ROOT/" && die "something is still mounted inside $RX3_ROOT; reboot, then run ./setup.sh again."
  ./build-rootfs.sh || die "build-rootfs.sh failed."
  ok "built at $RX3_ROOT"
fi

# --- 5. host side -----------------------------------------------------------------------------------------------
step "host install"
./install.sh || die "install.sh failed: see the lines above."
sudo systemctl enable rx3 >/dev/null 2>&1 && ok "the player starts at every boot"
systemctl is-active -q display-manager && REBOOT_NEEDED=1    # a running desktop holds the screen until a reboot

# --- 6. done ----------------------------------------------------------------------------------------------------
step "done"
echo "  Exit the player: hold SOURCE on the touchscreen for 5 s, or ESC on a keyboard."
echo "  Desktop back:    ./install.sh desktop"
if [ $REBOOT_NEEDED = 1 ]; then
  if [ $REBOOT = ask ]; then printf "  Reboot now to start the player? [Y/n] "; read -r a; case "$a" in n|N) REBOOT=no;; *) REBOOT=yes;; esac; fi
  if [ $REBOOT = yes ]; then echo "  Rebooting..."; sudo reboot; else echo "  Reboot when ready:  sudo reboot"; fi
else
  sudo systemctl restart rx3 && ok "player (re)started with the new build"
fi
