import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

// Popout content for the nyxWallpaper plugin.
//
// One chain, from browsing to downloading to applying. DMS' own picker only
// knows still images; the library on disk has both, so the panel gets two
// levels: All / Static / Live on top, the subfolders the files actually live in
// underneath. The sources that can be downloaded live in the same panel, so a
// collection you do not have yet is one click away from the tab it will appear
// in.
Item {
    id: panel

    readonly property int pad: Theme.spacingM
    readonly property string cli: SettingsData.getPluginSetting("nyxWallpaper", "cli", "")
                                  || (Quickshell.env("HOME") + "/.local/bin/nyxdeck")

    implicitWidth: 480
    implicitHeight: mainColumn.implicitHeight + pad * 2

    // injected by the popout
    property var closePopout: null
    property var parentPopout: null

    // ── i18n ─────────────────────────────────────────────────────────────────
    // Terms are the English text; translations/zh_CN.json carries the other
    // languages. I18n.trFor falls back to the DMS catalogue, then to the term.
    function tr(term, subst) {
        const text = I18n.trFor("nyxWallpaper", term);
        return subst === undefined ? text : text.replace("%1", subst);
    }

    // ── state ────────────────────────────────────────────────────────────────
    property int page: 0                  // 0 all | 1 static | 2 live | 3 sources
    property string chip: ""              // second level: a subfolder, "" = all
    property var items: []
    property var categories: []
    property var sources: []
    property var roots: []
    property string currentWallpaper: ""
    property string message: ""
    property bool busy: false

    readonly property var subfolders: {
        const ignore = ["all", "static", "live", "wallpapers", "pictures", "图片",
                        "video", "videos", "mpvpaper", "livewallpaper", "livewallpapers"];
        const out = [];
        for (const category of categories) {
            if (ignore.indexOf(String(category).toLowerCase()) >= 0 || out.indexOf(category) >= 0)
                continue;
            out.push(category);
        }
        return out;
    }

    readonly property var visibleItems: {
        const want = page === 1 ? "static" : (page === 2 ? "live" : "all");
        return items.filter(item => (want === "all" || item.group === want)
                                    && (chip === "" || item.category === chip));
    }

    readonly property int staticCount: items.filter(item => !item.video).length
    readonly property int liveCount: items.filter(item => item.video).length

    function isCurrent(item) {
        return currentWallpaper !== ""
            && (currentWallpaper === item.path || currentWallpaper === item.thumb);
    }

    function refresh() {
        busy = true;
        listProc.running = false;
        listProc.running = true;
        statusProc.running = false;
        statusProc.running = true;
        currentProc.running = false;
        currentProc.running = true;
    }

    function apply(item) {
        message = "";
        applyProc.command = [panel.cli, "wallpaper", "set", item.path];
        applyProc.running = false;
        applyProc.running = true;
    }

    function download(name) {
        message = tr("Downloading %1 …", name);
        downloadProc.command = [panel.cli, "wallpaper", "download", name];
        downloadProc.running = false;
        downloadProc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: listProc
        command: [panel.cli, "wallpaper", "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                panel.busy = false;
                try {
                    const data = JSON.parse(text);
                    panel.items = data.items || [];
                    panel.categories = data.categories || [];
                    panel.roots = data.roots || [];
                } catch (e) {
                    panel.message = panel.tr("nyxdeck wallpaper list did not answer with JSON");
                }
            }
        }
    }

    Process {
        id: statusProc
        command: [panel.cli, "wallpaper", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    panel.sources = JSON.parse(text).sources || [];
                } catch (e) {
                    panel.sources = [];
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
        id: applyProc
        onExited: (code) => {
            panel.message = code === 0 ? panel.tr("Applied") : panel.tr("Applying failed");
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

    ColumnLayout {
        id: mainColumn

        width: panel.implicitWidth - panel.pad * 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: panel.pad
        spacing: Theme.spacingS

        // ── header ───────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            DankIcon {
                name: "photo_library"
                size: Theme.iconSize
                color: Theme.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: panel.tr("Wallpapers")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                StyledText {
                    text: panel.tr("%1 static · %2 live", "").replace("%1", panel.staticCount)
                                                             .replace("%2", panel.liveCount)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            DankButton {
                text: panel.busy ? panel.tr("Working…") : panel.tr("Refresh")
                iconName: "refresh"
                enabled: !panel.busy
                onClicked: panel.refresh()
            }
        }

        // ── first level ──────────────────────────────────────────────────────
        DankButtonGroup {
            Layout.fillWidth: true
            maximumWidth: parent.width
            size: "small"
            checkEnabled: false
            minButtonWidth: Math.floor((parent.width - Theme.spacingS * 3) / 4)
            currentIndex: panel.page
            model: [panel.tr("All"), panel.tr("Static"), panel.tr("Live"), panel.tr("Sources")]
            onSelectionChanged: (index, selected) => {
                if (!selected || index < 0)
                    return;
                panel.page = index;
                panel.message = "";
            }
        }

        // ── second level ─────────────────────────────────────────────────────
        DankFilterChips {
            Layout.fillWidth: true
            visible: panel.page < 3 && panel.subfolders.length > 0
            chipHeight: 28
            model: [{
                "value": "",
                "label": panel.tr("Everything")
            }].concat(panel.subfolders.map(name => ({
                "value": name,
                "label": name
            })))
            currentIndex: Math.max(0, [""].concat(panel.subfolders).indexOf(panel.chip))
            onSelectionChanged: index => {
                const all = [""].concat(panel.subfolders);
                panel.chip = all[index] ?? "";
            }
        }

        // ── wallpapers ───────────────────────────────────────────────────────
        ListView {
            id: wallpaperList

            Layout.fillWidth: true
            visible: panel.page < 3
            height: Math.min(360, Math.max(64, panel.visibleItems.length * 60))
            clip: true
            spacing: 2
            model: panel.visibleItems
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData

                readonly property bool current: panel.isCurrent(modelData)

                width: wallpaperList.width
                height: 58
                radius: 10
                color: current ? Theme.primaryHoverLight
                               : (rowMouse.containsMouse ? Theme.surfaceHover : "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingXS
                    anchors.rightMargin: Theme.spacingS
                    spacing: Theme.spacingS

                    Item {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 42
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            anchors.fill: parent
                            visible: !modelData.video || modelData.thumb_ready
                            source: modelData.video
                                    ? ("file://" + modelData.thumb)
                                    : ("file://" + modelData.path)
                            sourceSize.width: 144
                            sourceSize.height: 84
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            layer.enabled: true
                        }

                        DankIcon {
                            anchors.centerIn: parent
                            visible: modelData.video && !modelData.thumb_ready
                            name: "movie"
                            size: Theme.iconSize
                            color: Theme.surfaceVariantText
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: modelData.title
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: current ? Font.Medium : Font.Normal
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        StyledText {
                            text: (modelData.video ? panel.tr("Live") : panel.tr("Static"))
                                  + "  ·  " + modelData.category
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    DankIcon {
                        visible: current
                        name: "check"
                        size: Theme.iconSize
                        color: Theme.primary
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.apply(modelData)
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: panel.page < 3 && panel.visibleItems.length === 0
            text: panel.tr("Nothing here yet. Sources can be downloaded from the Sources tab.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        // ── sources ──────────────────────────────────────────────────────────
        ListView {
            id: sourceList

            Layout.fillWidth: true
            visible: panel.page === 3
            height: Math.min(320, Math.max(64, panel.sources.length * 74))
            clip: true
            spacing: 2
            model: panel.sources
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData

                width: sourceList.width
                height: 72
                radius: 10
                color: Theme.surfaceContainerHigh

                RowLayout {
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
                            text: modelData.installed ? panel.tr("Downloaded")
                                                      : panel.tr("Not downloaded yet")
                            font.pixelSize: Theme.fontSizeSmall
                            color: modelData.installed ? Theme.primary : Theme.surfaceVariantText
                        }

                        StyledText {
                            visible: (modelData.note || "").length > 0
                            text: modelData.note || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    DankButton {
                        visible: !modelData.installed
                        text: panel.tr("Download")
                        iconName: "download"
                        enabled: !panel.busy
                        onClicked: panel.download(modelData.name)
                    }

                    DankIcon {
                        visible: modelData.installed === true
                        name: "check_circle"
                        size: Theme.iconSize
                        color: Theme.primary
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: panel.page === 3 && panel.sources.length === 0
            text: panel.tr("No sources configured. Add one with nyxdeck wallpaper sources add.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        // ── footer ───────────────────────────────────────────────────────────
        StyledText {
            Layout.fillWidth: true
            visible: panel.message.length > 0
            text: panel.message
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.primary
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            text: panel.page === 3
                  ? panel.tr("Nothing is downloaded until you press Download.")
                  : panel.tr("Left click applies. Video goes through mpvpaper, and DMS keeps the palette from a still frame.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: panel.roots.length > 0
            text: panel.roots.join("  ·  ")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            elide: Text.ElideMiddle
        }
    }
}
