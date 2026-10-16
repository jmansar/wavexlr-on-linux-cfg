-- BEGIN USER CONFIGURATION

CONFIG_WAVE_DEVICE = "WaveXLR Sink"
-- CONFIG_WAVE_DEVICE = "Wave3 Sink"
-- CONFIG_WAVE_DEVICE = "Wave1 Sink"
-- CONFIG_WAVE_DEVICE = "XLRDock Sink"

local CONFIG_SINKS = {
    { name = "virtual_music", description = "Music" },
    { name = "virtual_comms", description = "Comms" },
    { name = "virtual_game",  description = "Game" },
}

-- END USER CONFIGURATION

log = Log.open_topic("s-virtual-sinks")

log.notice("Initialize virtual-sinks");

virtual_sink_nodes = {}
virtual_sink_links = {}

local configured_monitor_aliases = {}
local configured_playback_aliases = {}
local port_interests = {}
local channels = { "FL", "FR" }

local function get_monitor_alias(sink, channel)
    return sink.description .. ":monitor_" .. channel
end

local function get_playback_alias(channel)
    return CONFIG_WAVE_DEVICE .. ":playback_" .. channel
end

for _, sink in ipairs(CONFIG_SINKS) do
    for _, channel in ipairs(channels) do
        local alias = get_monitor_alias(sink, channel)
        configured_monitor_aliases[alias] = true
        table.insert(port_interests, Interest {
            type = "port",
            Constraint { "port.alias", "=", alias, type = "pw-global" },
        })
    end
end

for _, channel in ipairs(channels) do
    local alias = get_playback_alias(channel)
    configured_playback_aliases[alias] = true
    table.insert(port_interests, Interest {
        type = "port",
        Constraint { "port.alias", "=", alias, type = "pw-global" },
    })
end

local ports = ObjectManager(port_interests)

local function create_link(output, input)
    local key = output.port_id .. ":" .. input.port_id
    if virtual_sink_links[key] then
        return
    end

    local link = Link("link-factory", {
        ["link.output.node"] = output.node_id,
        ["link.output.port"] = output.port_id,
        ["link.input.node"] = input.node_id,
        ["link.input.port"] = input.port_id,
    })

    if link then
        virtual_sink_links[key] = link
        link:activate(Feature.Proxy.BOUND, function(_, error)
            if error then
                log:warning("Failed to create link " .. output.alias .. " -> " .. input.alias
                    .. ": " .. tostring(error))
                virtual_sink_links[key] = nil
            else
                log:notice("Created link " .. output.alias .. " -> " .. input.alias)
            end
        end)
    end
end

local function endpoint(port)
    return {
        alias = port.properties["port.alias"],
        node_id = tostring(port.properties["node.id"]),
        port_id = tostring(port["bound-id"]),
    }
end

local function port_added(_, port)
    local properties = port.properties
    local alias = properties["port.alias"]
    local channel = properties["audio.channel"]
    if not channel then
        return
    end

    if configured_monitor_aliases[alias] then
        local target_alias = get_playback_alias(channel)
        for candidate in ports:iterate() do
            if candidate.properties["port.alias"] == target_alias then
                create_link(endpoint(port), endpoint(candidate))
            end
        end
    elseif configured_playback_aliases[alias] then
        for candidate in ports:iterate() do
            local candidate_properties = candidate.properties
            if configured_monitor_aliases[candidate_properties["port.alias"]]
                and candidate_properties["audio.channel"] == channel then
                create_link(endpoint(candidate), endpoint(port))
            end
        end
    end
end

ports:connect("object-added", port_added)
ports:activate()

for _, sink in ipairs(CONFIG_SINKS) do
    local sink_name = sink.name
    local sink_description = sink.description
    local properties = {
        ["factory.name"] = "support.null-audio-sink",
        ["node.name"] = sink_name,
        ["node.description"] = sink_description,
        ["media.class"] = "Audio/Sink",
        ["node.virtual"] = "true",
        ["audio.rate"] = 48000,
        ["audio.channels"] = 2,
        ["audio.position"] = "FL,FR",
        ["monitor.channel-volumes"] = "true",
    }

    local node = LocalNode("adapter", properties)
    node:activate(Feature.Proxy.BOUND, function(_, error)
        if error then
            log:warning("Failed to create virtual sink " .. sink_description
                .. ": " .. tostring(error))
        else
            log:notice("Created virtual sink " .. sink_description
                .. " (" .. sink_name .. ")")
        end
    end)

    table.insert(virtual_sink_nodes, node)
end
