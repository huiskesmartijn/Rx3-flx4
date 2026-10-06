#!/bin/bash
# Root helper for the chroot player. On USB STOP the firmware unmounts /media/usbN/<part> itself, but it runs
# unprivileged here (EPERM, then it retries every 10 s and finally shows E-8307), so fbshim.so forwards the request
# over the /dev/rx3-priv FIFO and this loop performs the unmount. The touch bridge, also unprivileged, sends "stop"
# here when SOURCE is held to exit the player. Started by rx3-start.sh as unit rx3-priv.
. "$(dirname "$(readlink -f "$0")")/rx3-env.sh"
R=$RX3_ROOT; H=$RX3_HOME; F=$R/dev/rx3-priv
[ -p $F ] || mkfifo $F; chmod 622 $F; chown root:root $F      # firmware writes, only root reads
exec 3<>$F
while read -r cmd arg <&3; do
  case "$cmd" in
    umount)
      [[ $arg =~ ^/media/usb[12]/[A-Za-z0-9]+$ ]] || continue
      sync
      if mountpoint -q "$R$arg"; then umount "$R$arg" 2>/dev/null || umount -l "$R$arg"; fi
      $H/rx3-mtab.sh; logger -t rx3 "firmware unmounted $arg (USB STOP)" ;;
    stop)
      # SOURCE held 5 s on the touchscreen (touch-bridge.c): stop the player, as ESC does on a keyboard.
      # --no-block, because rx3-stop.sh stops this helper too.
      logger -t rx3 "SOURCE held on the touchscreen: stopping the player"
      systemctl --no-block stop rx3 ;;
  esac
done
