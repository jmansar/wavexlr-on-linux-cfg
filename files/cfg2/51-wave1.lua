rule = {
    matches = {
        {
            { "node.name", "matches", "alsa_input.usb-Elgato_Systems_Elgato_Wave_1_*" },
        }
    },
    apply_properties = {
        ["node.always-process"] = true,
    },
}

table.insert(alsa_monitor.rules, rule)
