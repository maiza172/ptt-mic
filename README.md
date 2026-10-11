# ptt-mic

Hold one mouse button to unmute the default PipeWire microphone. Release mutes it again.

Discord and Vesktop on GNOME Wayland do not receive mouse buttons for their own push-to-talk. This mutes the source those apps are already capturing, so an open mic sends silence until the button is held.

The physical device is grabbed and every event except the configured button is replayed through a virtual pointer. The button does not also act as Back. The default source stays muted while the button is up, including when the service starts and when it stops.

Tested on Bazzite GNOME Wayland with a Logitech G309, where mouse 4 is `BTN_SIDE`. The device name and button come from a config file.

## Requirements

- Python 3 with `python3-evdev` (`import evdev`)
- PipeWire with `/usr/bin/wpctl`
- A writable `/dev/uinput`
- A session that can already read the real mouse (logind does this for the active seat)

Both `python3-evdev` and `wpctl` ship on current Bazzite images. Nothing needs to be layered with `rpm-ostree`. Membership in group `input` is not required.

## Install

```sh
git clone https://github.com/maiza172/ptt-mic.git
cd ptt-mic
./install.sh
```

`install.sh` copies the script, a config if you do not already have one, and a user service. It does not touch `/etc`. Install the udev rule it prints:

```sh
sudo install -m 644 udev/65-ptt-mic.rules /etc/udev/rules.d/65-ptt-mic.rules
sudo udevadm control --reload-rules
systemctl --user daemon-reload
systemctl --user enable --now ptt-mic.service
```

Edit `~/.config/ptt-mic/config` before relying on the button. `device_name` must match the evdev name exactly.

```
device_name = Logitech G309
button = BTN_SIDE
```

`ptt-mic --list-devices` prints every event node it can open, with the usual mouse buttons. `BTN_SIDE` is the rear thumb button (mouse 4). `BTN_EXTRA` is the front one (mouse 5). A numeric evdev code is also accepted. Optional `virt_name` overrides the virtual pointer name. The default is `<device_name> pointer`.

```sh
ptt-mic --print-config
journalctl --user -u ptt-mic.service -e
```

A successful start logs `grabbed ... BTN_SIDE is push-to-unmute only`. A second open of that event node then fails with "Device or resource busy".

## Microphone

Press and release run:

```sh
wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0   # press: unmute
wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1   # release: mute
```

The source is whichever PipeWire currently marks as the default. Check it with `wpctl status`. This is system mute, not the mute icon inside Discord.

`PTT_MIC_CONFIG` overrides the config path. `PTT_MIC_WPCTL` overrides the `wpctl` binary, which is useful for a dry run.

## The udev rule

`/etc/udev/rules.d/65-ptt-mic.rules`:

```
ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{phys}=="input-remapper/ptt-mic*", ENV{ID_BUS}="usb", TAG+="uaccess"
```

The virtual device's `phys` is `input-remapper/ptt-mic`. That prefix makes input-remapper's autoload rule skip it. The file is numbered `65-` so it runs before `70-mouse.rules` and `71-seat.rules`: `ID_BUS=usb` is set in time for the mouse hwdb match, and `uaccess` is set in time for the seat tag. The active session can then read the clone.

The service waits up to five seconds for that node to be readable. If it is not, or if the grab fails, it listens without grabbing and logs that the rule is needed. In that mode the button still changes mute, and it also keeps its normal action (Back, for mouse 4).

Run one instance. Every clone uses the same `phys`. A second copy will not grab the real mouse while the first holds it.

`systemctl --user stop ptt-mic.service` releases the grab. The physical mouse is the pointer again immediately.

## Logitech mice and Solaar

Solaar rules run only after a button is diverted to HID++ notifications. Diversion needs the reprogrammable-controls feature (`0x1B04`). Mice that have it, and that show Key/Button Diversion in Solaar, should use that. A diverted button never reaches the desktop, so there is nothing to swallow.

The G309 LIGHTSPEED (WPID `40B1`) does not implement that feature. Solaar 1.1.20 records `reprogrammable-keys` and `divert-keys` as absent, and it only names `MOUSE_BUTTON_SPY` (`0x8110`). On-board profiles on that mouse are read-only. Solaar rules on `Back` never match. Flatpak Solaar also cannot run `wpctl`: Execute is one program name, and the sandbox has no PipeWire socket.

## Layout

| File | Role |
| --- | --- |
| `ptt-mic` | The watcher |
| `config.example` | `device_name` and `button` |
| `udev/65-ptt-mic.rules` | Seat access for the virtual pointer |
| `systemd/user/ptt-mic.service` | User service, after PipeWire |
| `install.sh` | Copy the user files and print the root command |

`ptt-mic --self-test` checks frame handling without opening a device or changing mute.

Released under the MIT license.
