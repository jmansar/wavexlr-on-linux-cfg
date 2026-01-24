rule = {
    matches = {
        {
            { "node.name", "matches", "alsa_input.usb-Elgato_Systems_Elgato_Wave_XLR_*" },
        }
    },
    apply_properties = {
        ["node.always-process"] = true,
    },
}

table.insert(alsa_monitor.rules, rule)
