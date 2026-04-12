rule = {
    matches = {
        {
            { "node.name", "matches", "alsa_input.usb-Elgato_Systems_Elgato_Wave_3_*" },
        }
    },
    apply_properties = {
        ["node.always-process"] = true,
    },
}

table.insert(alsa_monitor.rules, rule)
