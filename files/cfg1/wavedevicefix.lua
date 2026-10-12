-- Fix for Wave XLR / Wave 3 / Wave 1 / XLR Dock microphone not working while playback is active.
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

CONFIG_SETTLE_DELAY_MS = 1500

CONFIG_POLL_INTERVAL_MS = 100

CONFIG_MAX_WAIT_MS = 10000

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
elseif scriptArgs["device"] == "wave1" then
    CONFIG_WAVE_DEVICE_SOURCE_NAME = "wave1-source"
    CONFIG_WAVE_DEVICE_SINK_NAME = "wave1-sink"
    CONFIG_WAVE_DEVICE_DISPLAY_NAME = "Wave1"

    log.notice("Use configuration for Wave1 device")
elseif scriptArgs["device"] == "xlrdock" then
    CONFIG_WAVE_DEVICE_SOURCE_NAME = "xlrdock-source"
    CONFIG_WAVE_DEVICE_SINK_NAME = "xlrdock-sink"
    CONFIG_WAVE_DEVICE_DISPLAY_NAME = "XLRDock"

    log.notice("Use configuration for XLRDock device")
else
    log.notice("Use configuration for WaveXLR device")
end


waveDeviceSourceOm = ObjectManager {
    Interest {
        type = "node",
        Constraint { "node.name", "matches", CONFIG_WAVE_DEVICE_SOURCE_NAME },
    }
}

devicesOm = ObjectManager {
    Interest {
        type = "device",
    }
}

-- One port ObjectManager for the lifetime of the script.
portOm = ObjectManager {
    Interest {
        type = "port",
    }
}

waveDeviceSinkNode = nil
nullSinkForWaveDeviceSource = nil
nullSinkLink = nil

generation = 0

function currentWaveDeviceSource()
    for node in waveDeviceSourceOm:iterate() do
        return node
    end
    return nil
end

function findPort(nodeId, direction)
    local found = nil
    local interest = Interest {
        type = "port",
        Constraint { "node.id", "equals", nodeId },
        Constraint { "port.direction", "equals", direction }
    }

    for port in portOm:iterate(interest) do
        found = port
    end

    return found
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

        local sinkNode = Node("adapter", sinkNodeProperties)
        waveDeviceSinkNode = sinkNode
        sinkNode:activate(Feature.Proxy.BOUND, function(n, err)
            if err then
                log:warning("Failed to create " .. sinkNodeProperties["node.name"]
                    .. ": " .. tostring(err))
                if waveDeviceSinkNode == sinkNode then
                    waveDeviceSinkNode = nil
                end
            else
                log:notice("Created custom " ..
                    CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " sink. object.id: " .. n.properties["object.id"])
            end
        end)

        return
    end
end

function scheduleWaveDeviceSink(gen)
    local waitedMs = 0
    local runningMs = 0
    local stateWarned = false

    log:notice("Waiting for " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source to run for " ..
        CONFIG_SETTLE_DELAY_MS .. " ms before creating the sink")

    Core.timeout_add(CONFIG_POLL_INTERVAL_MS, function()
        if gen ~= generation or waveDeviceSinkNode then
            return false
        end

        local sourceNode = currentWaveDeviceSource()
        if not sourceNode then
            return false
        end

        waitedMs = waitedMs + CONFIG_POLL_INTERVAL_MS

        local ok, state = pcall(function() return sourceNode.state end)
        local running
        if ok and state ~= nil then
            running = (tostring(state) == "running")
        else
            if not stateWarned then
                log:warning("Cannot read " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME ..
                    " source state, using a fixed delay instead")
                stateWarned = true
            end
            running = true
        end

        if running then
            runningMs = runningMs + CONFIG_POLL_INTERVAL_MS
        else
            runningMs = 0
        end

        if runningMs >= CONFIG_SETTLE_DELAY_MS then
            log:notice(CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source has been running for " ..
                runningMs .. " ms (waited " .. waitedMs .. " ms in total)")
            createWaveDeviceSink(sourceNode)
            return false
        end

        if waitedMs >= CONFIG_MAX_WAIT_MS then
            log:warning(CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source did not stay running within " ..
                CONFIG_MAX_WAIT_MS .. " ms (state: " .. tostring(state) ..
                "). Creating the sink anyway, the microphone may be silent")
            createWaveDeviceSink(sourceNode)
            return false
        end

        return true
    end)
end

function tryCreateLinkForWaveDeviceSource()
    if nullSinkLink or not nullSinkForWaveDeviceSource then
        return
    end

    local sourceNode = currentWaveDeviceSource()
    if not sourceNode then
        return
    end

    local sourceId = sourceNode.properties["object.id"]
    local nullSinkId = nullSinkForWaveDeviceSource.properties["object.id"]
    if not sourceId or not nullSinkId then
        return
    end

    local outPort = findPort(sourceId, "out")
    local inPort = findPort(nullSinkId, "in")
    if not outPort or not inPort then
        return
    end

    local outPortId = outPort.properties["object.id"]
    local inPortId = inPort.properties["object.id"]
    if not outPortId or not inPortId then
        return
    end

    local args = {
        ["link.input.node"] = nullSinkId,
        ["link.input.port"] = inPortId,

        ["link.output.node"] = sourceId,
        ["link.output.port"] = outPortId,
    }

    log:notice("Creating link between null sink and " ..
        CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source. Ports: " ..
        args["link.input.node"] ..
        "-" ..
        args["link.input.port"] .. " -> " .. args["link.output.node"] .. "-" .. args["link.output.port"])

    local gen = generation
    local link = Link("link-factory", args)
    nullSinkLink = link

    link:activate(Feature.Proxy.BOUND, function(l, err)
        if err then
            log:warning("Failed to create link between null sink and " ..
                CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source"
                .. ": " .. tostring(err))
            if nullSinkLink == link then
                nullSinkLink = nil
            end
        else
            log:notice("Created link between null sink and " .. CONFIG_WAVE_DEVICE_DISPLAY_NAME .. " source")
            if gen == generation and nullSinkLink == link then
                scheduleWaveDeviceSink(gen)
            end
        end
    end)
end

function onWaveDeviceSourceAdded(_, node)
    generation = generation + 1
    tryCreateLinkForWaveDeviceSource()
end

function onWaveDeviceSourceRemoved()
    generation = generation + 1

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

function onNullSinkCreated()
    log:notice("Activate event listeners");

    portOm:connect("object-added", tryCreateLinkForWaveDeviceSource)
    portOm:activate()
    waveDeviceSourceOm:connect("object-added", onWaveDeviceSourceAdded)
    waveDeviceSourceOm:connect("object-removed", onWaveDeviceSourceRemoved)
    waveDeviceSourceOm:activate()
end

nullSinkForWaveDeviceSource = createNullSink();
devicesOm:activate()

log:notice("script initialized")
