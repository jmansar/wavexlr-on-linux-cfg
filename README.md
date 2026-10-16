# Wave XLR on Linux

Unofficial instructions to fix issues with Wave XLR (also Wave 1, Wave 3 and XLR Dock) on Linux.

As of November 2024, Wave XLR does not have official Linux support - [Elgato Wave XLR - System Requirements](https://help.elgato.com/hc/en-us/articles/4404864886157-Elgato-Wave-XLR-System-Requirements).

However, since the device is recognized by the system as a standard USB audio device, some functionality can be accessed on Linux.

> **Disclaimer**: The instructions and information on this page are unofficial and not endorsed or supported by device manufacturer - Elgato. 
> The content of this page is based on my personal experience and may not work in all cases.
> I cannot guarantee the accuracy or reliability of the information provided. Use at your own risk. No warranties or guarantees, express or implied, are provided.

These instructions assume your Linux distribution uses [pipewire](https://pipewire.org/) and [wireplumber](https://pipewire.pages.freedesktop.org/wireplumber/) `>=0.5`.

## Solutions

- [Fix missing microphone audio](#fix-missing-microphone-audio)
- [Configure virtual audio - Music, Comms, Game etc.](#configure-virtual-audio---music-comms-game-etc)

### Fix missing microphone audio

When you use the device for both audio input (a microphone) and audio output (headphones or speakers), the microphone may fail to capture audio. This occurs when audio playback starts before the microphone input is active.

The steps below configure WirePlumber to create the audio output only after the microphone input has been activated. A custom script creates a virtual output and links it to the microphone input, ensuring that microphone capture starts and remains active.

##### Step 1. Disable the autoconfigured playback sink and define a custom Lua script.

Create the directory if it doesn't exist `~/.config/wireplumber/wireplumber.conf.d/`:
```
mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
```

For Wave XLR: create [~/.config/wireplumber/wireplumber.conf.d/51-wavexlr.conf](./files/cfg1/51-wavexlr.conf) file.

For Wave 3: create [~/.config/wireplumber/wireplumber.conf.d/51-wave3.conf](./files/cfg1/51-wave3.conf) file.

For Wave 1: create [~/.config/wireplumber/wireplumber.conf.d/51-wave1.conf](./files/cfg1/51-wave1.conf) file.

For XLR Dock: create [~/.config/wireplumber/wireplumber.conf.d/51-xlrdock.conf](./files/cfg1/51-xlrdock.conf) file.

##### Step 2. Create a custom wireplumber script.

Create the directory if it doesn't exist `~/.local/share/wireplumber/scripts/`:
```
mkdir -p ~/.local/share/wireplumber/scripts/
```

Create the file [~/.local/share/wireplumber/scripts/wavedevicefix.lua](./files/cfg1/wavedevicefix.lua)

> **IMPORTANT**
> If you’re upgrading from a version released before December 2025, be aware that the script file has been renamed from `wavexlrfix.lua` to `wavedevicefix.lua`. Make sure to also replace your old configuration file with the updated version provided above.


### Configure virtual audio - Music, Comms, Game etc.

Virtual audio outputs make it possible to route applications into separate categories. For example, you can send a music player to **Music**, a voice-chat application to **Comms**, and a game to **Game**. All three outputs are played through the Wave device, so you can still hear them normally.

Each virtual output can also be captured separately. This is useful for streaming and recording because you can choose which categories your audience or recording will hear. For example, you can capture **Game** and **Comms** while excluding **Music**, even though you can hear all three through your headphones or speakers.

This configuration uses the Wave device output created by the previous section, so complete those steps first.

##### Step 1. Install the virtual sinks script.

Create the WirePlumber scripts directory if it does not already exist:

```
mkdir -p ~/.local/share/wireplumber/scripts/
```

Create the file [~/.local/share/wireplumber/scripts/virtual-sinks.lua](./files/virtual-sinks.lua).

At the beginning of the script, make sure `CONFIG_WAVE_DEVICE` matches your device. Uncomment only the appropriate line:

```lua
CONFIG_WAVE_DEVICE = "WaveXLR Sink"
-- CONFIG_WAVE_DEVICE = "Wave3 Sink"
-- CONFIG_WAVE_DEVICE = "Wave1 Sink"
-- CONFIG_WAVE_DEVICE = "XLRDock Sink"
```

You can also edit `CONFIG_SINKS` to add, remove, or rename the virtual outputs.

##### Step 2. Configure WirePlumber to load the script.

Create the file [~/.config/wireplumber/wireplumber.conf.d/52-virtual-sinks.conf](./files/52-virtual-sinks.conf).

Restart WirePlumber to apply the configuration:

```
systemctl restart --user wireplumber
```

The **Music**, **Comms**, and **Game** outputs should now appear in your system's audio settings. Select the appropriate output for each application.


#### Troubleshooting

If the configuration does not work as expected, try restarting WirePlumber:
```
systemctl restart --user wireplumber
```

To view wireplumber logs 
```
journalctl -u wireplumber --user --lines 30
```

## Changelog

### 2026-10-12
* Waits for source to be running before creating the sink. [#38](https://github.com/jmansar/wavexlr-on-linux-cfg/pull/38)

### 2026-04-12
* Revert to using original workaround for the microphone issue. [#31](https://github.com/jmansar/wavexlr-on-linux-cfg/pull/31)

### 2026-03-20
* Add instructions for Wave 1. Reported in [#27](https://github.com/jmansar/wavexlr-on-linux-cfg/issues/27).

### 2026-02-15
* Add instructions for XLR Dock. Reported in [#25](https://github.com/jmansar/wavexlr-on-linux-cfg/issues/25).

### 2026-01-24
* Add instructions for wireplumber 0.4 which is used on older systems. Reported in [#18](https://github.com/jmansar/wavexlr-on-linux-cfg/issues/18).

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
