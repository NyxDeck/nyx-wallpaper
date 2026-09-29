import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Bar pill: one glyph, left click opens the panel (DMS' default for a plugin
// that ships popoutContent). The panel is where the state lives, so the pill
// stays out of the way.
PluginComponent {
    id: root

    layerNamespacePlugin: "nyxwallpaper"

    component PillContent: Item {
        implicitWidth: pillIcon.implicitWidth + Theme.spacingS * 2
        implicitHeight: root.widgetThickness

        DankIcon {
            id: pillIcon
            anchors.centerIn: parent
            name: "photo_library"
            size: Theme.iconSize
            color: Theme.widgetIconColor
        }
    }

    horizontalBarPill: Component {
        PillContent {}
    }

    verticalBarPill: Component {
        PillContent {}
    }

    popoutWidth: 420
    popoutHeight: 520
    popoutContent: Component {
        NyxWallpaperPanel {}
    }
}
