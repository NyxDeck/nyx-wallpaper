import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

// Popout content for the nyxWallpaper plugin.
//
// Deliberately small. Browsing wallpapers is already solved twice over: DMS'
// own picker (still images only) and the GTK picker on Mod+W, which is ours and
// handles live video too. What is *not* solved anywhere else is reachable from
// the bar, so this panel only holds that: the current wallpaper, a way to jump
// to the next one, a way to get to the picker in one click, and the download
// chain for collections.
Item {
    id: panel

    readonly property int pad: Theme.spacingM
    readonly property string cli: SettingsData.getPluginSetting("nyxWallpaper", "cli", "")
                                  || (Quickshell.env("HOME") + "/.local/bin/nyxdeck")
    readonly property string picker: Paths.strip(Paths.config) + "/niri/scripts/wallpaper-picker.py"

    implicitWidth: 420
    implicitHeight: mainColumn.implicitHeight + pad * 2

    property var closePopout: null
    property var parentPopout: null

    // Local components, same as the mihomo panel uses: DMS ships neither.
    component Chip: Rectangle {
        id: chip

        property string label: ""
        property string icon: ""
        property bool active: false
        signal tapped

        implicitWidth: chipRow.implicitWidth + Theme.spacingM * 2
        implicitHeight: 28
        radius: 14
        opacity: chip.enabled ? 1 : 0.5

        color: {
            if (chipArea.pressed)
                return active ? Theme.primaryHoverLight : Theme.surfacePressed;
            if (chipArea.containsMouse)
                return active ? Theme.primaryHoverLight : Theme.surfaceHover;
            return active ? Theme.primaryHoverLight : Theme.surfaceLight;
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DankIcon {
                visible: chip.icon.length > 0
                name: chip.icon
                size: Theme.fontSizeSmall
                color: chip.active ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                visible: chip.label.length > 0
                text: chip.label
                font.pixelSize: Theme.fontSizeSmall
                font.weight: chip.active ? Font.Medium : Font.Normal
                color: chip.active ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: chip.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: chip.tapped()
        }
    }

    component FieldLabel: StyledText {
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.surfaceVariantText
    }

    // ── i18n ─────────────────────────────────────────────────────────────────
    function tr(term, subst) {
        const text = I18n.trFor("nyxWallpaper", term);
        return subst === undefined ? text : text.replace("%1", subst);
    }

    // ── state ────────────────────────────────────────────────────────────────
    property var sources: []
    property var roots: []
    property int staticCount: 0
    property int liveCount: 0
    property string currentWallpaper: ""
    property bool currentIsLive: false
    property string message: ""

    function refresh() {
        statusProc.running = false;
        statusProc.running = true;
        listProc.running = false;
        listProc.running = true;
        currentProc.running = false;
        currentProc.running = true;
    }

    function next(videoOnly) {
        message = "";
        nextProc.command = videoOnly
            ? [panel.cli, "wallpaper", "next", "--video"]
            : [panel.cli, "wallpaper", "next"];
        nextProc.running = false;
        nextProc.running = true;
    }

    function download(name) {
        message = tr("Downloading %1 …", name);
        downloadProc.command = [panel.cli, "wallpaper", "download", name];
        downloadProc.running = false;
        downloadProc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: statusProc
        command: [panel.cli, "wallpaper", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    panel.sources = data.sources || [];
                    panel.roots = data.roots || [];
                    panel.staticCount = data.static || 0;
                    panel.liveCount = data.video || 0;
                } catch (e) {
                    panel.message = panel.tr("nyxdeck did not answer with JSON");
                }
            }
        }
    }

    Process {
        id: listProc
        command: [panel.cli, "wallpaper", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Only used to find out whether what DMS is showing belongs to
                // a video: for those DMS keeps the still frame, not the file.
                try {
                    const items = JSON.parse(text).items || [];
                    panel.currentIsLive = items.some(item => item.video
                                                          && item.thumb === panel.currentWallpaper);
                } catch (e) {
                    panel.currentIsLive = false;
                }
            }
        }
    }

    Process {
        id: currentProc
        command: ["dms", "ipc", "call", "wallpaper", "get"]
        stdout: StdioCollector {
            onStreamFinished: panel.currentWallpaper = text.trim()
        }
    }

    Process {
        id: nextProc
        onExited: (code) => {
            panel.message = code === 0 ? panel.tr("Switched") : panel.tr("Switching failed");
            panel.refresh();
        }
    }

    Process {
        id: downloadProc
        onExited: (code) => {
            panel.message = code === 0 ? panel.tr("Download finished") : panel.tr("Download failed");
            panel.refresh();
        }
    }

    Column {
        id: mainColumn

        width: panel.implicitWidth - panel.pad * 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: panel.pad
        spacing: Theme.spacingM

        // ── current wallpaper ────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: Theme.spacingXS

            RowLayout {
                width: parent.width
                spacing: Theme.spacingS

                FieldLabel {
                    text: panel.tr("Wallpapers")
                    Layout.fillWidth: true
                }

                Chip {
                    label: panel.tr("Refresh")
                    icon: "refresh"
                    onTapped: panel.refresh()
                }
            }

            StyledText {
                text: panel.currentIsLive
                      ? panel.tr("A live video wallpaper is running")
                      : panel.tr("A still wallpaper is set")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Item {
                width: parent.width
                height: 112
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Theme.surfaceContainerHigh
                }

                Image {
                    anchors.fill: parent
                    visible: panel.currentWallpaper !== ""
                    source: panel.currentWallpaper === "" ? "" : ("file://" + panel.currentWallpaper)
                    sourceSize.width: 840
                    sourceSize.height: 224
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: panel.currentWallpaper === ""
                    text: panel.tr("No wallpaper set")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            StyledText {
                width: parent.width
                text: panel.tr("%1 static · %2 live in the library", "")
                        .replace("%1", panel.staticCount).replace("%2", panel.liveCount)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        // ── what only this panel can do ──────────────────────────────────────
        Column {
            width: parent.width
            spacing: Theme.spacingS

            RowLayout {
                width: parent.width
                spacing: Theme.spacingS

                Chip {
                    label: panel.tr("Next wallpaper")
                    icon: "skip_next"
                    onTapped: panel.next(false)
                }

                Chip {
                    label: panel.tr("Next live")
                    icon: "movie"
                    onTapped: panel.next(true)
                }

                Chip {
                    label: panel.tr("Open picker")
                    icon: "grid_view"
                    onTapped: Quickshell.execDetached([panel.picker])
                }
            }

            StyledText {
                width: parent.width
                text: panel.tr("Browsing is the picker's job; it handles still and live wallpapers, with categories and search.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }

        // ── download chain ───────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: Theme.spacingS

            FieldLabel {
                text: panel.tr("Collections")
            }

            Repeater {
                model: panel.sources

                delegate: Rectangle {
                    required property var modelData

                    width: mainColumn.width
                    height: sourceRow.implicitHeight + Theme.spacingS * 2
                    radius: 10
                    color: Theme.surfaceContainerHigh

                    RowLayout {
                        id: sourceRow

                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingS

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: modelData.name
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: modelData.installed
                                      ? panel.tr("Downloaded")
                                      : (modelData.note || panel.tr("Not downloaded yet"))
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }

                        Chip {
                            visible: !modelData.installed
                            label: panel.tr("Download")
                            icon: "download"
                            onTapped: panel.download(modelData.name)
                        }

                        StyledText {
                            visible: modelData.installed === true
                            text: panel.tr("Ready")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                        }
                    }
                }
            }

            StyledText {
                width: parent.width
                visible: panel.sources.length === 0
                text: panel.tr("No collections configured. Add one with nyxdeck wallpaper sources add.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                text: panel.tr("Nothing is downloaded until you press Download. New collections land in %1.").replace("%1", panel.roots.length > 0 ? panel.roots[0] : "~/Pictures/Wallpapers")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }

        StyledText {
            width: parent.width
            visible: panel.message.length > 0
            text: panel.message
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.primary
            wrapMode: Text.WordWrap
        }
    }
}
