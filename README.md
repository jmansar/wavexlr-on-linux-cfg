# Wave XLR on Linux - issues and workarounds 

Wave XLR does not have an official support on Linux at this time (24/11/2024) - [Elgato Wave XLR - System Requirements](https://help.elgato.com/hc/en-us/articles/4404864886157-Elgato-Wave-XLR-System-Requirements).

However, because Wave XLR is recognized by the system as a standard USB audio device, some of its functionality seems to be accessible on Linux.

This README details my experience with getting the device to work on my machine.

> **Disclaimer**: The instructions and information on this page are unofficial and not endorsed or supported by device manufacturer - Elgato. 
> The content of this page is based on my personal experience and may not work in all cases.
> I cannot guarantee the accuracy or reliability of the information provided. Use at your own risk. No warranties or guarantees, express or implied, are provided.

## Issues

### No audio signal from the microphone

There is no audio from the microphone when device is also used for playback.

This is an issue that I experienced with a default configuration on Arch Linux. Also, checked the same issue happening on Ubuntu 24.04.
Here are the posts of people that had the same issue:
* [endeavouros forum post](https://forum.endeavouros.com/t/cannot-use-mic-when-output-input-are-selected-on-sound-device/43275/13)
* [pipewire issue #3587](https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/3587)

After some trial and error, I found that the issue is most likely not related to [pipewire](https://pipewire.org/) and is more lower-level. It's reproducible with playback and recording from raw ALSA devices without pipewire or pulseaudio running.

If you start playing an audio and then initiate recording from the microphone, there is no signal detected from the microphone. However, when the process is reversed, starting the recording first than playback, everything seems to work fine.

#### The workaround

The following workaround is not a proper fix for the problem, but makes the device usable with both headphones and microphone working.
The idea is to start the microphone capture before any use of the device output sink. 

These instructions assume that your Linux distribution use [pipewire](https://pipewire.org/) and [wireplumber](https://pipewire.pages.freedesktop.org/wireplumber/).

##### Step 1. Disable autoconfigured sink (playback) node for Wave XLR device in wireplumber. Define custom lua script to execute.

Create file [~/.config/wireplumber/wireplumber.conf.d/51-wavexlr.conf](./files/51-wavexlr.conf)

##### Step 2. Create custom wireplumber script.

Create file [~/.local/share/wireplumber/scripts/wavexlrfix.lua](./files/wavexlrfix.lua)

#### Notes

The steps above configure wireplumber to ensure Wave XLR playback node is created after the source (microphone) node is activated.
The script creates a virtual sink node and a link between the node and Wave XLR microphone source. This way it forces the device to start a capture.
Only after the link is initialized, the script creates a sink (playback) node for Wave XLR.

Known problems:
* Unplugging and plugging Wave XLR results in no signal from the microphone. In order to fix - restart wireplumber - `systemctl restart --user wireplumber` or toggle the profile back and forth for Wave XLR device in `pavucontrol`.


Please feel free to raise an issue on this repository if you would like to suggest an improvement to these instructions.

