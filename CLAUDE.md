# Notes for Claude

This is Martijn's private copy of Rx3-flx4 (XDJ-RX3 firmware on a Raspberry Pi 5 with a DDJ-FLX4 and a
Waveshare 10.1" DSI panel). Read `MY-SETUP.md` first: hardware, config.txt, install, and a dated log of what
was changed and why. Work on branch `claude/eloquent-rubin-guv4dm`.

## Open to-dos: remind the user of these at the start of the conversation

- [ ] Delete the old public fork `huiskesmartijn/Rx3-flx4` (GitHub: Settings -> Danger zone), after checking
      `huiskesmartijn/rx3-flx4-private` shows as Private with both branches. Until then changes are pushed to both.
- [ ] On the Pi, switch to the private repository: `sudo apt install -y gh && gh auth login`, then
      `cd ~/Rx3-flx4 && git remote set-url origin https://github.com/huiskesmartijn/rx3-flx4-private.git && git pull`.
- [ ] Then run `./setup.sh` on the Pi: first real test of the one-command install, and it installs
      hold-SOURCE-5-s-to-exit.
- [ ] Cover art is not shown. Diagnose with the commands in `MY-SETUP.md` ("Cover art") and paste the output.
- [ ] Later: decide where the four sidebar buttons go (full-screen 1280x800 mode).

Tick an item off (or delete it) once the user confirms it is done.
