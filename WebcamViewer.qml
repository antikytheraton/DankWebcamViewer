import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    pluginId: "webcamViewer"
    layerNamespacePlugin: "webcamViewer"

    // -----------------------------------------------------------------------
    // Player settings
    // -----------------------------------------------------------------------
    property string player: pluginData.player || "vlc"
    property var players: ({
            vlc: (title, url) => "vlc --qt-start-minimized --meta-title='" + title + "' '" + url + "'",
            ffplay: (title, url) => "ffplay -rtsp_transport tcp -window_title '" + title + "' '" + url + "' -loglevel error -an",
            mpv: (title, url) => "mpv --no-terminal --mute=yes --title=" + title + " " + url
        })
    // -----------------------------------------------------------------------
    // Camera list
    // -----------------------------------------------------------------------
    property var cameras: {
        const raw = pluginData.cameras;
        if (!raw || !Array.isArray(raw) || raw.length === 0) {
            return [
            // {
            //     name: "Camera 1",
            //     url: "rtsp://",
            //     enabled: true
            // }
            ];
        }
        return raw;
    }

    property var enabledCameras: cameras.filter(c => c.enabled !== false)

    // -----------------------------------------------------------------------
    // Process tracking  { "Camera Name": Process { ... }, ... }
    // -----------------------------------------------------------------------
    property var runningStreams: ({})

    function isRunning(name) {
        return !!runningStreams[name];
    }

    function strippedUrl(url) {
        const u = url.replace(/\/\/[^@]+@/, "//");
        return u.length > 38 ? u.substring(0, 35) + "…" : u;
    }

    property int activeCount: 0   // kept in sync manually so the bar reacts

    function launchCamera(cam) {
        if (isRunning(cam.name))
            // already open

            return;
        const title = cam.name.replace(/'/g, "'\\''");
        const url = cam.url.replace(/'/g, "'\\''");
        const buildCmd = players[player];

        const proc = processComponent.createObject(root, {
            cameraName: cam.name,
            command: ["sh", "-c", buildCmd(title, url)]
        });
        proc.running = true;

        // store & notify
        runningStreams[cam.name] = proc;
        runningStreams = runningStreams;   // trigger binding refresh
        activeCount = Object.keys(runningStreams).length;

        ToastService.showInfo("Webcam Viewer", "Opening " + cam.name + "…");
    }

    function stopCamera(name) {
        const proc = runningStreams[name];
        if (!proc)
            return;
        proc.running = false;
        delete runningStreams[name];
        runningStreams = runningStreams;
        activeCount = Object.keys(runningStreams).length;
        ToastService.showInfo("Webcam Viewer", name + " stopped.");
    }

    function calcPopoutHeight() {
        const rows = Math.ceil(enabledCameras.length / 2);
        const cardH = (420 - Theme.spacingS * 3) / 2 * 0.65;
        return Math.max(220, 130 + rows * (cardH + Theme.spacingS));
    }

    // -----------------------------------------------------------------------
    // Process component
    // -----------------------------------------------------------------------
    Component {
        id: processComponent

        Process {
            property string cameraName: ""

            onExited: {
                delete runningStreams[cameraName];
                runningStreams = runningStreams;
                activeCount = Object.keys(runningStreams).length;
                destroy();
            }
        }
    }

    // -----------------------------------------------------------------------
    // Bar label — shows active count when streams are running
    // -----------------------------------------------------------------------
    property string barLabel: {
        if (activeCount > 0)
            return activeCount + "/" + enabledCameras.length + " live";
        return enabledCameras.length + " cam" + (enabledCameras.length !== 1 ? "s" : "");
    }

    property color barIconColor: activeCount > 0 ? Theme.primary : Theme.outlineVariant

    // ========================================================================
    // HORIZONTAL BAR PILL
    // ========================================================================
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            // Green activity dot
            Rectangle {
                visible: root.activeCount > 0
                width: 7
                height: 7
                radius: 4
                color: "#4caf50"
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    running: root.activeCount > 0
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.3
                        duration: 900
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1.0
                        duration: 900
                        easing.type: Easing.InOutSine
                    }
                }
            }

            DankIcon {
                name: "videocam"
                size: root.iconSize
                color: root.barIconColor
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }

            StyledText {
                text: root.barLabel
                font.pixelSize: Theme.fontSizeMedium
                color: root.activeCount > 0 ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }
        }
    }

    // ========================================================================
    // VERTICAL BAR PILL
    // ========================================================================
    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            // Activity dot
            Rectangle {
                visible: root.activeCount > 0
                width: 7
                height: 7
                radius: 4
                color: "#4caf50"
                anchors.horizontalCenter: parent.horizontalCenter

                SequentialAnimation on opacity {
                    running: root.activeCount > 0
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.3
                        duration: 900
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1.0
                        duration: 900
                        easing.type: Easing.InOutSine
                    }
                }
            }

            DankIcon {
                name: "videocam"
                size: root.iconSize
                color: root.barIconColor
                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }

            StyledText {
                text: root.activeCount > 0 ? root.activeCount + "/" + root.enabledCameras.length : root.enabledCameras.length.toString()
                font.pixelSize: Theme.fontSizeSmall
                color: root.activeCount > 0 ? Theme.primary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ========================================================================
    // POPOUT
    // ========================================================================
    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Webcam Viewer"
            detailsText: {
                if (root.enabledCameras.length === 0)
                    return "No cameras configured — open Settings to add some.";
                if (root.activeCount > 0)
                    return root.activeCount + " stream(s) live. Click ■ to stop.";
                return "Click a camera to open its stream.";
            }
            showCloseButton: true

            // ── Empty state ────────────────────────────────────────────────
            StyledText {
                visible: root.enabledCameras.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "No cameras enabled"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                topPadding: Theme.spacingL
            }

            // ── Camera grid ────────────────────────────────────────────────
            Flow {
                visible: root.enabledCameras.length > 0
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: root.enabledCameras

                    delegate: StyledRect {
                        id: camCard

                        required property var modelData
                        required property int index

                        property bool live: root.isRunning(modelData.name)
                        // force re-evaluation when runningStreams changes
                        property var _watch: root.runningStreams

                        width: (popout.width - Theme.spacingS * 3) / 2
                        height: camCard.width * 0.65
                        radius: Theme.cornerRadius

                        color: live ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (cardMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)

                        border.color: live ? Theme.primary : "transparent"
                        border.width: live ? 1 : 0

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        // ── Live dot (top-left) ────────────────────────────
                        Rectangle {
                            visible: camCard.live
                            width: 8
                            height: 8
                            radius: 4
                            color: "#4caf50"
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: Theme.spacingXS

                            SequentialAnimation on opacity {
                                running: camCard.live
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0.3
                                    duration: 900
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 1.0
                                    duration: 900
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        // ── Stop button (top-right, only when live) ────────
                        MouseArea {
                            id: stopArea
                            visible: camCard.live
                            width: Theme.iconSizeSmall + Theme.spacingXS * 2
                            height: width
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Theme.spacingXS
                            cursorShape: Qt.PointingHandCursor

                            // Eat the click so it doesn't bubble to cardMouse
                            onClicked: {
                                root.stopCamera(camCard.modelData.name);
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadius / 2
                                color: stopArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.25) : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "stop"
                                    size: Theme.iconSizeSmall
                                    color: Theme.error
                                }
                            }
                        }

                        // ── Card body ──────────────────────────────────────
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DankIcon {
                                name: camCard.live ? "videocam" : "videocam_off"
                                size: Theme.iconSizeLarge
                                color: camCard.live ? Theme.primary : (cardMouse.containsMouse ? Theme.primary : Theme.surfaceVariantText)
                                anchors.horizontalCenter: parent.horizontalCenter

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }

                            StyledText {
                                text: camCard.modelData.name
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: camCard.live ? Theme.primary : Theme.surfaceText
                                anchors.horizontalCenter: parent.horizontalCenter
                                elide: Text.ElideRight
                                width: camCard.width - Theme.spacingM * 2
                                horizontalAlignment: Text.AlignHCenter

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }

                            StyledText {
                                text: camCard.live ? "● LIVE" : root.strippedUrl(camCard.modelData.url)
                                font.pixelSize: Theme.fontSizeSmall
                                color: camCard.live ? "#4caf50" : Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                                elide: Text.ElideRight
                                width: camCard.width - Theme.spacingM * 2
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // ── Main click area (launch) ───────────────────────
                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: camCard.live ? Qt.ArrowCursor : Qt.PointingHandCursor
                            // Don't intercept clicks on the stop button
                            enabled: !camCard.live

                            onClicked: {
                                root.launchCamera(camCard.modelData);
                                // keep popout open so user can launch more cameras
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 420
    popoutHeight: root.calcPopoutHeight()
}
