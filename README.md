# Wave XLR on Linux - issues and workarounds 

Wave XLR does not have an official support on Linux at this time (24/11/2024) - [Elgato Wave XLR - System Requirements](https://help.elgato.com/hc/en-us/articles/4404864886157-Elgato-Wave-XLR-System-Requirements).

However, because Wave XLR is recognized by the system as a standard USB audio device, some of its functionality seems to be accessible on Linux.

This README documents my experience with getting the device to work on my machine.

> **Disclaimer**: The instructions and information on this page are unofficial and not endorsed or supported by device manufacturer - Elgato. 
> The content of this page is based on my personal experience and may not work in all cases.
> I cannot guarantee their accuracy or reliability. Use at your own risk. No warranties or guarantees, express or implied, are provided.

## Issues

### No audio signal from the microphone

There is no audio from the microphone when device is also used for playback.

This is an issue that I experienced with a default configuration on Arch Linux. Also, checked the same issue happening on Ubuntu 24.04.
Here are the posts of people that had the same issue:
* [endeavouros forum post](https://forum.endeavouros.com/t/cannot-use-mic-when-output-input-are-selected-on-sound-device/43275/13)
* [pipewire issue #3587](https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/3587)

After some trial and error, I found that the issue is most likely not related to [pipewire](https://pipewire.org/) and is more lower-level. It's reproducible with playback and recording from raw ALSA devices without pipewire or pulseaudio running.

When you start playing an audio and then initiate recording from the microphone, there is no signal from the microphone. However, when the process is reversed, starting the recording first than playback, everything seems to work fine.

#### The workaround

The following workaround is not a proper fix for the problem, but makes the device usable with both headphones and microphone working.
The idea is to start the microphone recording before any use of the device output sinks. 

These instructions assume that your Linux distribution use [pipewire](https://pipewire.org/), [wireplumber](https://pipewire.pages.freedesktop.org/wireplumber/) and [systemd](https://systemd.io/).

1. Create custom device nodes for Wave XLR in pipewire configuration. 

File `~/.config/pipewire/pipewire.conf.d/wavexlr.conf`:
```
context.objects = [
    { factory = adapter
        args = {
            factory.name           = api.alsa.pcm.source
            node.name              = "custom-wavexlr-mic"
            node.description       = "WaveXLR Mic"
            media.class            = "Audio/Source"
            api.alsa.path          = "hw:XLR,0"
            priority.driver        = 2000
            priority.session       = 2000
            node.driver            = true
        }
    }
    { factory = adapter
        args = {
            factory.name           = api.alsa.pcm.sink
            node.name              = "custom-wavexlr-sink"
            node.description       = "WaveXLR Headphones"
            media.class            = "Audio/Sink"
            api.alsa.path          = "hw:XLR,0"
            alsa.resolution_bits   = 24
            audio.channels         = 2
            audio.position         = "FL,FR"
        }
    }
]
```

1. Disable auto discovered Wave XLR device in wireplumber. 

File `~/.config/wireplumber/wireplumber.conf.d/wavexlr.conf`:
```
monitor.alsa.rules = [
  {
    matches = [
      {
        device.name = "~alsa_card.usb-Elgato_Systems_Elgato_Wave_XLR_*"
      }
    ]
    actions = {
      update-props = {
        device.disabled = true
      }
    }
  }
]
```

1. Create a script to start audio recording and make it executable.

File `~/scripts/wavexlr-record.sh`:
```sh
#!/bin/bash

RECORD=true

_term() { 
  RECORD=false
  echo "Terminating recording" 
  kill -TERM "$PID" 2>/dev/null
}

trap _term SIGTERM

while $RECORD
do
    echo "Attempt record from microphone" 
    pw-record --target "custom-wavexlr-mic" /dev/null &
    PID=$!

    wait "$PID"
done
```

```
chmod +x ~/scripts/wavexlr-record.sh 
```

1. Create systemd service unit to launch the record script.

File `~/.config/systemd/user/pipewire-wavexlr-workaround.service`:
```
[Unit]
Description=WaveXLR mic issue workaround

[Service]
ExecStart=bash "%h/scripts/wavexlr-record.sh"
ExecStartPost=/bin/sleep 1
```

1. Create systemd service override for pipewire.

File `~/.config/systemd/user/pipewire.socket.d/override.conf`:
```
[Unit]
Requires=pipewire-wavexlr-workaround.service
```

#### Notes

The steps above configure a script to continuously attempt to start recording via pipewire, aiming to trigger the recording as soon as pipewire finishes starting up. The recorded audio is not saved as it is directed to `/dev/null` device.
Due to the nature of this setup, it is inherently prone to a race condition.

In my testing on my machine I didn't experience any issues so far. The microphone gets activated before the playback, and both function correctly.
One side effect of this approach is that a desktop environment reports microphone as being used continuously, which might be indicated, for example, by a red microphone icon in Gnome top bar.

There is likely a better way to achieve this behaviour. Please feel free to raise an issue on this repository if you would like to suggest an improvement.

What did not work:
* Stopping the recording after the initial launch.
The microphone eventually stops functioning if the recording gets stopped.

* Rely on wireplumber to initialize devices.
I found this workaround not working most of the time when the device is handled by wireplumber.
