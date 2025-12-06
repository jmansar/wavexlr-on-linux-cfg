-- Fix for Wave XLR / Wave 3 microphone not working while playback is active.
-- https://github.com/jmansar/wavexlr-on-linux-cfg
--
-- This script creates a link between Wave device source (mirophone input) and a virtual null sink (output)
-- in order to force the device to start a microphone capture before the playback is activated.
-- After the link is estabilished it creates Wave device sink (playback output).

-- BEGIN USER CONFIGURATION

-- If you need to customize the sink node that is created by the script
-- you can add the additional properties below
CONFIG_SINK_ADDITIONAL_PROPERTIES = {
    -- disables session suspend on idle for the sink playback
    -- helps with potential audio playback delays and audio popping
    ["session.suspend-timeout-seconds"] = "0"
}

-- END USER CONFIGURATION
log = Log.open_topic("s-wavedevicefix")

-- read arguments passed to the script from the wireplumber config file
local scriptArgs = ...
if scriptArgs ~= nil then
    scriptArgs = scriptArgs:parse(1)
else
    scriptArgs = {}
end

CONFIG_WAVE_DEVICE_SOURCE_NAME = "wavexlr-source"
CONFIG_WAVE_DEVICE_SINK_NAME = "wavexlr-sink"
CONFIG_WAVE_DEVICE_DISPLAY_NAME = "WaveXLR"

if scriptArgs["device"] == "wave3" then
    CONFIG_WAVE_DEVICE_SOURCE_NAME = "wave3-source"
    CONFIG_WAVE_DEVICE_SINK_NAME = "wave3-sink"
    CONFIG_WAVE_DEVICE_DISPLAY_NAME = "Wave3"

    log.notice("Use configuration for Wave3 device")
else
    log.notice("Use configuration for WaveXLR device")
end


waveDeviceSourceOm = ObjectManager {
    Interest {
        type = "node",
        Constraint { "node.name", "matches", CONFIG_WAVE_DEVICE_SOURCE_NAME },
    }
}

linkOm = ObjectManager {
    Interest {
        type = "link",
    }
}

devicesOm = ObjectManager {
    Interest {
        type = "device",
    }
}

waveDeviceSinkNode = nil
nullSinkForWaveDeviceSource = nil
nullSinkLink = nil

function createLinkForWaveDeviceSource(waveDeviceSourceNode)
    local outPort = nil
    local inPort = nil

    local outInterest = Interest {
        type = "port",
        Constraint { "node.id", "equals", waveDeviceSourceNode.properties["object.id"] },
        Constraint { "port.direction", "equals", "out" }
    }

    local inInterest = Interest {
        type = "port",
        Constraint { "node.id", "equals", nullSinkForWaveDeviceSource.properties["object.id"] },
        Constraint { "port.direction", "equals", "in" }
    }

    local portOm = ObjectManager {
        Interest {
            type = "port",
        }
    }

    function onPortAdded()
        if not nullSinkLink then
            for port in portOm:iterate(outInterest) do
                outPort = port
            end

            for port in portOm:iterate(inInterest) do
                inPort = port
            end

            if inPort and outPort and inPort.properties["object.id"] and outPort.properties["object.id"] then
                local args = {
                    ["link.input.node"] = nullSinkForWaveDeviceSource.properties["object.id"],
                    ["link.input.port"] = inPort.properties["object.id"],

                    ["link.output.node"] = waveDeviceSourceNode.properties["object.id"],
                    ["link.output.port"] = outPort.properties["object.id"],
                }

                log:notice("Creating link between null sink and " ..
                    CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source. Ports: " ..
                    args["link.input.node"] ..
                    "-" ..
                    args["link.input.port"] .. " -> " .. args["link.output.node"] .. "-" .. args["link.output.port"])

                nullSinkLink = Link("link-factory", args)

                nullSinkLink:activate(Feature.Proxy.BOUND, function(n, err)
                    if err then
                        log:warning("Failed to create link between null sink and " ..
                            CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source"
                            .. ": " .. tostring(err))
                        node = nil
                    else
                        log:notice("Created link between null sink and " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source")
                    end
                end)
            end
        end
    end

    portOm:connect("object-added", onPortAdded)
    portOm:activate()
end

function onLinkCreated(_, link)
    if nullSinkLink and link.properties["object.id"] == nullSinkLink.properties["object.id"] then
        for node in waveDeviceSourceOm:iterate() do
            createWaveDeviceSink(node)
        end
    end
end

function createWaveDeviceSink(sourceNode)
    local deviceInterest = Interest {
        type = "device",
        Constraint { "object.id", "equals", sourceNode.properties["device.id"] }
    }

    for device in devicesOm:iterate(deviceInterest) do
        local sinkNodeProperties = {
            ["device.id"] = sourceNode.properties["device.id"],
            ["factory.name"] = "api.alsa.pcm.sink",
            ["node.name"] = CONFIG_WAVE_DEVICE_SINK_NAME,
            ["node.description"] = CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " Sink",
            ["node.nick"] = CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " Sink",
            ["media.class"] = "Audio/Sink",
            ["api.alsa.path"] = sourceNode.properties["api.alsa.path"],
            ["api.alsa.pcm.card"] = sourceNode.properties["api.alsa.pcm.card"],
            ["api.alsa.pcm.stream"] = "playback",
            ["alsa.resolution_bits"] = "24",
            ["audio.channels"] = "2",
            ["audio.position"] = "FL,FR",
            ["priority.driver"] = "1000",
            ["priority.session"] = "1000",
            ["node.pause-on-idle"] = "false",
            ["card.profile.device"] = "3",
            ["device.profile.description"] = "Analog Stereo",
            ["device.profile.name"] = "analog-stereo",
            ["port.group"] = "playback",
        }

        for k, v in pairs(device.properties) do
            if k:find("^api%.alsa%.card%..*") then
                sinkNodeProperties[k] = v
            end
        end

        for k, v in pairs(CONFIG_SINK_ADDITIONAL_PROPERTIES) do
            sinkNodeProperties[k] = v
        end

        log:notice("Creating custom " ..
            CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " sink. api.alsa.path: " .. sourceNode.properties["api.alsa.path"])

        waveDeviceSinkNode = Node("adapter", sinkNodeProperties)
        waveDeviceSinkNode:activate(Feature.Proxy.BOUND, function(n, err)
            if err then
                log:warning("Failed to create " .. sinkNodeProperties["node.name"]
                    .. ": " .. tostring(err))
                waveDeviceSinkNode = nil
            else
                log:notice("Created custom " ..
                    CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " sink. object.id: " .. n.properties["object.id"])
            end
        end)
    end
end

function onWaveDeviceSourceAdded(_, node)
    createLinkForWaveDeviceSource(node)
end

function createNullSink()
    local properties = {
        ["factory.name"] = "support.null-audio-sink",
        ["node.name"] = "null-sink-for-" .. CONFIG_WAVE_DEVICE_SOURCE_NAME,
        ["node.description"] = "Null Sink For " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " Source - do not use",
        ["node.nick"] = "Null Sink For " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " Source - do not use",
        ["media.class"] = "Audio/Sink",
        ["monitor.channel-volumes"] = "true",
        ["monitor.passthrough"] = "true",
        ["audio.channels"] = "1",
        ["audio.position"] = "MONO",
        ["node.passive"] = "false"
    }

    log:notice("Creating custom null sink for " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " Source")

    local node = Node("adapter", properties)

    node:activate(Feature.Proxy.BOUND, function(n, err)
        if err then
            log:warning("Failed to create " .. properties["node.name"]
                .. ": " .. tostring(err))
            node = nil
        else
            log:notice("Created null sink for " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source. object.id: " ..
                n.properties["object.id"])
            onNullSinkCreated();
        end
    end)

    return node
end

function onWaveDeviceSourceRemoved()
    if waveDeviceSinkNode then
        log:notice("Removing custom " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " sink");
        waveDeviceSinkNode:request_destroy()
        waveDeviceSinkNode = nil
    end

    if nullSinkLink then
        log:notice("Removing null sink link");
        nullSinkLink:request_destroy()
        nullSinkLink = nil
    end
end

function onNullSinkCreated()
    log:notice("Activate event listeners");

    linkOm:activate()
    linkOm:connect("object-added", onLinkCreated)
    waveDeviceSourceOm:connect("object-added", onWaveDeviceSourceAdded)
    waveDeviceSourceOm:connect("object-removed", onWaveDeviceSourceRemoved)
    waveDeviceSourceOm:activate()
end

nullSinkForWaveDeviceSource = createNullSink();
devicesOm:activate()

log:notice("script initialized")
