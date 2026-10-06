# My setup: Pi 5 + Waveshare 10.1" DSI + DDJ-FLX4

Notes for this particular build, so they survive between sessions. The general instructions are in
[`INSTALL.md`](INSTALL.md); this file only records what is specific to this hardware.

## Hardware

- Raspberry Pi 5, official 27 W USB-C supply (the FLX4 can brown out a weaker one).
- **Waveshare 10.1inch DSI LCD (C)**: 1280x800, landscape, capacitive touch over the DSI ribbon.
  Identified from the `config.txt` on the SD card Waveshare shipped with it.
  1280x800 is exactly the XDJ-RX3's own screen resolution.
- Pioneer DDJ-FLX4 as controller and sound card.

## Branch

This branch (`claude/eloquent-rubin-guv4dm`) starts from upstream's `7inch` branch
(`mutlisensor/Rx3-flx4`), not `main`. On a 1280x800 panel that layout gives the firmware picture
1152x720 with bilinear scaling and a 128 px sidebar of four buttons (SOURCE, BROWSE, USB STOP 1/2).
`main` would shrink it to about 1066x666 to fit on-screen faders the FLX4 makes redundant.

Planned later: a full-screen 1280x800 mode (firmware at 1:1) with the four sidebar buttons moved to
an edge-swipe overlay and/or FLX4 SHIFT combinations.

## OS

Fresh **Raspberry Pi OS (64-bit)**, hostname `FLX4PI` (`ssh <user>@flx4pi.local`), flashed with Raspberry Pi Imager (user, Wi-Fi and SSH
set in Imager). The SD card Waveshare shipped held a stock Raspberry Pi OS desktop image of
2026-06-18 with their display lines added; it is fine as a hardware test but not used for the build.

## config.txt

Appended to `/boot/firmware/config.txt`: the `[pi5]` block from Waveshare's own card, which matches
the two lines in the panel's printed manual:

```
[pi5]
dtoverlay=nospi10
dtoverlay=ov5647
dtoverlay=vc4-kms-dsi-waveshare-panel,10_1_inch,dsi0
[all]
```

- The ribbon goes in the Pi 5 connector marked **0** (CAM/DISP 0), because of `,dsi0`.
  For connector 1, drop `,dsi0`.
- `ov5647` is the Pi Camera v1 sensor driver. Waveshare's manual includes it with this panel, so it is
  kept; without a camera it only logs that none was found. `nospi10` came from the card, not the manual.
- Waveshare's card also had `enable_uart=1`; not needed.
- The panel must be connected at boot; the framebuffer is not created on hotplug.

## Install, on the Pi

```bash
git clone -b claude/eloquent-rubin-guv4dm https://github.com/huiskesmartijn/Rx3-flx4.git
cd Rx3-flx4/rx3-handoff && chmod +x *.sh
./install.sh deps
python3 recover-firmware.py && python3 extract_cramfs.py
./install.sh doctor
./build-rootfs.sh
./install.sh
sudo systemctl enable --now rx3
```

Not with `sudo` for the clone: the files must belong to the login user.

## Things to check on first run

- `./install.sh doctor` should list the display as a `/dev/fbN` whose name contains `dsi`.
  If it picks the wrong one, put `RX3_FB=/dev/fbN` in `rx3-handoff/rx3.conf`.
- Rotation should be 0 (landscape panel). If upside down: `RX3_ROTATE=180` in `rx3.conf`.
- Touch should be picked up automatically as the pointer (`~/rx3-touch.log` shows the ranges).

## Log

- 2026-10-06: panel identified, branch created from `7inch`, OS choice and config.txt lines recorded.
