import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// ---------------------------------------------------------------------------
// WebcamViewerSettings.qml
//
// Lets the user manage a list of RTSP cameras.
// Each camera has: name (string), url (string), enabled (bool).
//
// The list is stored as a JSON array under the key "cameras" in plugin_settings.
// ---------------------------------------------------------------------------

PluginSettings {
    id: root
    pluginId: "webcamViewer"

    // ── Working copy of the camera list ─────────────────────────────────────
    property var cameraList: {
        const stored = root.loadValue("cameras", null);
        if (!stored || !Array.isArray(stored) || stored.length === 0) {
            return [];
        }
        return stored;
    }

    function saveCameraList() {
        root.saveValue("cameras", cameraList);
    }

    function addCamera() {
        cameraList = cameraList.concat([
            {
                name: "New Camera",
                url: "",
                enabled: true
            }
        ]);
        saveCameraList();
    }

    function removeCamera(index) {
        const copy = cameraList.slice();
        copy.splice(index, 1);
        cameraList = copy;
        saveCameraList();
    }

    function updateCamera(index, key, value) {
        const copy = JSON.parse(JSON.stringify(cameraList)); // deep copy
        copy[index][key] = value;
        cameraList = copy;
        saveCameraList();
    }

    // ── Header ───────────────────────────────────────────────────────────────
    StyledText {
        width: parent.width
        text: "Webcam Viewer"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure RTSP streams. Credentials in the URL are hidden in the popout."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "player"
        label: "Player"
        description: "Choose the player to use for webcam popouts (mpv/vlc/ffplay)"
        options: [
            {
                label: "vlc (default)",
                value: "vlc"
            },
            {
                label: "ffplay",
                value: "ffplay"
            },
            {
                label: "mpv",
                value: "mpv"
            },
        ]
        defaultValue: "vlc"
    }

    // ── Camera list ──────────────────────────────────────────────────────────
    Repeater {
        id: cameraRepeater
        model: root.cameraList.length

        delegate: StyledRect {
            id: camEntry
            required property int index

            width: parent.width
            // height grows to wrap content
            implicitHeight: entryCol.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Column {
                id: entryCol
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Theme.spacingM
                }
                spacing: Theme.spacingS

                // ── Row: camera # label + enable toggle + delete ─────────────
                RowLayout {
                    width: parent.width

                    StyledText {
                        text: "Camera " + (camEntry.index + 1)
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        Layout.fillWidth: true
                    }

                    // Enabled toggle (small)
                    StyledText {
                        text: root.cameraList[camEntry.index]?.enabled !== false ? "Enabled" : "Disabled"
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.cameraList[camEntry.index]?.enabled !== false ? Theme.primary : Theme.surfaceVariantText
                    }

                    MouseArea {
                        width: Theme.iconSize
                        height: Theme.iconSize
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const current = root.cameraList[camEntry.index]?.enabled !== false;
                            root.updateCamera(camEntry.index, "enabled", !current);
                        }

                        DankIcon {
                            anchors.fill: parent
                            name: root.cameraList[camEntry.index]?.enabled !== false ? "toggle_on" : "toggle_off"
                            color: root.cameraList[camEntry.index]?.enabled !== false ? Theme.primary : Theme.outlineVariant
                        }
                    }

                    // Delete button
                    MouseArea {
                        width: Theme.iconSize
                        height: Theme.iconSize
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.removeCamera(camEntry.index)

                        DankIcon {
                            anchors.fill: parent
                            name: "delete"
                            color: Theme.error
                        }
                    }
                }

                // ── Name field ──────────────────────────────────────────────
                StyledText {
                    text: "Display name"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                // DMS doesn't expose a raw TextInput widget in PluginSettings
                // context, so we use a styled Rectangle + TextInput combo.
                Rectangle {
                    width: parent.width
                    height: nameInput.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius / 2
                    color: Theme.surfaceContainer
                    border.color: nameInput.activeFocus ? Theme.primary : Theme.outlineVariant
                    border.width: 1

                    TextInput {
                        id: nameInput
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: Theme.spacingS
                        }
                        text: root.cameraList[camEntry.index]?.name ?? ""
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        selectByMouse: true
                        clip: true

                        onEditingFinished: root.updateCamera(camEntry.index, "name", text)
                    }
                }

                // ── URL field ────────────────────────────────────────────────
                StyledText {
                    text: "RTSP URL  (credentials included are fine — they're stripped in the popout)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Rectangle {
                    width: parent.width
                    height: urlInput.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius / 2
                    color: Theme.surfaceContainer
                    border.color: urlInput.activeFocus ? Theme.primary : Theme.outlineVariant
                    border.width: 1

                    TextInput {
                        id: urlInput
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: Theme.spacingS
                        }
                        text: root.cameraList[camEntry.index]?.url ?? ""
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: "monospace"
                        selectByMouse: true
                        clip: true

                        onEditingFinished: root.updateCamera(camEntry.index, "url", text)
                    }
                }
            }
        }
    }

    // ── Add camera button ────────────────────────────────────────────────────
    StyledRect {
        width: parent.width
        height: Theme.iconSize + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: addMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            DankIcon {
                name: "add_circle"
                size: Theme.iconSize
                color: Theme.primary
            }

            StyledText {
                text: "Add Camera"
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.primary
            }
        }

        MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.addCamera()
        }
    }

    // ── Footer note ──────────────────────────────────────────────────────────
    StyledText {
        width: parent.width
        text: "Streams are launched with ffplay using -rtsp_transport tcp.\n" + "Make sure ffmpeg/ffplay is installed on your system."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}
