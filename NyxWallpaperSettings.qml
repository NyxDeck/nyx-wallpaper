import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    id: root

    pluginId: "nyxWallpaper"

    StringSetting {
        settingKey: "cli"
        label: I18n.trFor("nyxWallpaper", "nyxdeck command")
        description: I18n.trFor("nyxWallpaper", "The command that owns the wallpaper chain. Empty means ~/.local/bin/nyxdeck.")
        defaultValue: ""
    }
    ToggleSetting {
        settingKey: "clear_mpvpaper_on_external"
        label: I18n.trFor("nyxWallpaper", "Clear live wallpapers when DMS picks one")
        description: I18n.trFor("nyxWallpaper", "When DMS' own picker or cycling sets a still image, stop mpvpaper so that image is actually visible.")
        defaultValue: true
    }
}
