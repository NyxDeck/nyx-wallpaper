import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Daemon surface.
//
// The panel is the front end; this exists for two things it cannot do itself:
// keeping mpvpaper and DMS' own wallpaper setting from fighting, and giving
// keybinds something to call.
//
// DMS' bar picker and its cycling only know still images. If one of them sets a
// wallpaper while a video is playing, the video stays on top of it and the
// palette is extracted from a picture nobody can see. SessionData tells us when
// the wallpaper changed and to what, so anything that is not the still frame we
// handed over means somebody else did it.
PluginComponent {
    id: root

    property var popoutService: null

    // The still frame (or plain image) DMS was told about last, by us.
    property string lastApplied: ""

    readonly property string cli: SettingsData.getPluginSetting("nyxWallpaper", "cli", "")
                                  || (Quickshell.env("HOME") + "/.local/bin/nyxdeck")
    readonly property bool clearOnExternal:
        SettingsData.getPluginSetting("nyxWallpaper", "clear_mpvpaper_on_external", true) !== false

    function runCli(args) {
        cliProc.command = [root.cli].concat(args);
        cliProc.running = false;
        cliProc.running = true;
    }

    // The CLI answers with {"applied": true, "item": {"path": ..., "thumb": ...}};
    // remember what DMS ends up showing, which is the thumbnail for a video.
    function rememberApplied(json) {
        try {
            const data = JSON.parse(json);
            const item = data.item || {};
            root.lastApplied = item.video ? (item.thumb || "") : (item.path || "");
        } catch (e) {
            root.lastApplied = "";
        }
    }

    Process {
        id: cliProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: root.rememberApplied(text)
        }
    }

    Process {
        id: clearProc
        command: ["pkill", "-x", "mpvpaper"]
        onExited: root.lastApplied = ""
    }

    Connections {
        target: SessionData

        function onWallpaperPathChanged() {
            if (!root.clearOnExternal)
                return;
            const now = SessionData.wallpaperPath || "";
            if (now === "" || now === root.lastApplied)
                return;                      // ours, or nothing to react to
            // Somebody else picked a still image: drop the live layer so their
            // choice is actually visible, and forget our still frame.
            clearProc.running = false;
            clearProc.running = true;
        }
    }

    IpcHandler {
        target: "nyxWallpaper"

        function refresh(): string {
            root.runCli(["wallpaper", "list", "--json"]);
            return "REFRESHED";
        }

        function apply(path: string): string {
            if (!path || path === "")
                return "ERROR: apply needs a path";
            root.runCli(["wallpaper", "set", path, "--json"]);
            return "APPLYING: " + path;
        }

        function next(): string {
            root.runCli(["wallpaper", "next", "--json"]);
            return "NEXT";
        }

        function nextVideo(): string {
            root.runCli(["wallpaper", "next", "--video", "--json"]);
            return "NEXT_VIDEO";
        }

        function status(): string {
            return root.lastApplied === "" ? "IDLE" : ("APPLIED: " + root.lastApplied);
        }
    }
}
