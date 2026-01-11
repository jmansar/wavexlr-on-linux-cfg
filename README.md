# Wave XLR on Linux

Unofficial instructions to fix issues with Wave XLR (and also Wave 3) on Linux.

As of November 2024, Wave XLR does not have official Linux support - [Elgato Wave XLR - System Requirements](https://help.elgato.com/hc/en-us/articles/4404864886157-Elgato-Wave-XLR-System-Requirements).

However, since the device is recognized by the system as a standard USB audio device, some functionality can be accessed on Linux.

> **Disclaimer**: The instructions and information on this page are unofficial and not endorsed or supported by device manufacturer - Elgato. 
> The content of this page is based on my personal experience and may not work in all cases.
> I cannot guarantee the accuracy or reliability of the information provided. Use at your own risk. No warranties or guarantees, express or implied, are provided.

## Issues

### No audio signal from the microphone

When the device is used for both playback and recording, the microphone produces no audio signal.

Other users have reported the same issue:
* [endeavouros forum post](https://forum.endeavouros.com/t/cannot-use-mic-when-output-input-are-selected-on-sound-device/43275/13)
* [pipewire issue #3587](https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/3587)

After some trial and error, I found that the issue is most likely not related to [pipewire](https://pipewire.org/) and is more low-level. It's reproducible with playback and recording from raw ALSA devices without pipewire or pulseaudio running.

If you start playing an audio and then initiate recording from the microphone, there is no signal detected from the microphone. However, when the process is reversed, starting the recording first then playback, everything seems to work fine.

#### The workaround (NEW)

These instructions assume your Linux distribution uses [pipewire](https://pipewire.org/) and [wireplumber](https://pipewire.pages.freedesktop.org/wireplumber/).

Create the directory if it doesn't exist `~/.config/wireplumber/wireplumber.conf.d/`:
```
mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
```

For Wave XLR: create [~/.config/wireplumber/wireplumber.conf.d/51-wavexlr.conf](./files/51-wavexlr.conf) file.

For Wave 3: create [~/.config/wireplumber/wireplumber.conf.d/51-wave3.conf](./files/51-wave3.conf) file.

The configuration sets the `node.always-process` property to `true` on the device source node (microphone input).
 
#### The workaround (OLD)

If you experience issues with the new approach, here is the original workaround:

The steps below configure wireplumber so that Wave XLR playback node is created only after the microphone source is activated.
A custom script creates a virtual sink node and links it to the Wave XLR microphone source, forcing the device to start and keep the microphone capture active.

> It was reported that the same workaround works for Wave 3 microphones - [Works for Wave 3 too](https://github.com/jmansar/wavexlr-on-linux-cfg/issues/10)

##### Step 1. Disable the autoconfigured playback sink and define a custom Lua script.

Create the directory if it doesn't exist `~/.config/wireplumber/wireplumber.conf.d/`:
```
mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
```

For Wave XLR: create [~/.config/wireplumber/wireplumber.conf.d/51-wavexlr.conf](./files/old/51-wavexlr.conf) file.

For Wave 3: create [~/.config/wireplumber/wireplumber.conf.d/51-wave3.conf](./files/old/51-wave3.conf) file.

##### Step 2. Create a custom wireplumber script.

Create the directory if it doesn't exist `~/.local/share/wireplumber/scripts/`:
```
mkdir -p ~/.local/share/wireplumber/scripts/
```

Create the file [~/.local/share/wireplumber/scripts/wavedevicefix.lua](./files/old/wavedevicefix.lua)

> [!IMPORTANT]  
> If you’re upgrading from a version released before December 2025, be aware that the script file has been renamed from `wavexlrfix.lua` to `wavedevicefix.lua`. Make sure to also replace your old configuration file with the updated version provided above.

#### Troubleshooting

If the workaround fails, try restarting the wireplumber:
```
systemctl restart --user wireplumber
```

To view wireplumber logs 
```
journalctl -u wireplumber --user --lines 30
```

## Changelog

### 2026-01-11
* Add instructions for a new, much simpler workaround reported in [#15](https://github.com/jmansar/wavexlr-on-linux-cfg/issues/15).

### 2025-12-06

* Fix intermittent failures when creating a null sink link. [#12](https://github.com/jmansar/wavexlr-on-linux-cfg/pull/12)
* Add instructions for Wave 3, adjust the config and the script. [#13](https://github.com/jmansar/wavexlr-on-linux-cfg/pull/13)
* Set `session.suspend-timeout-seconds: 0` on the device sink. [#13](https://github.com/jmansar/wavexlr-on-linux-cfg/pull/13)

### 2025-11-29
* Add device profile properties to WaveXLR Sink for audio mixer compatibility. [#11](https://github.com/jmansar/wavexlr-on-linux-cfg/pull/11)

## Contributing

If you'd like to suggest improvements to these instructions, please raise an issue or a PR on this [repository](https://github.com/jmansar/wavexlr-on-linux-cfg).

## License

[MIT License](https://github.com/jmansar/wavexlr-on-linux-cfg/blob/main/LICENSE)
