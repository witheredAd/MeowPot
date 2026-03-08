import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Dialogs

ApplicationWindow {
    id: window
    visible: true
    width: 1200
    height: 800
    title: "MeowPot"
    color: "#1e1e1e"

    // Material theme settings natively available in QML
    Material.theme: Material.Dark
    Material.accent: Material.LightBlue

    property bool rightPanelVisible: true
    property bool controlBarVisible: true

    Timer {
        id: hideControlsTimer
        interval: 3000
        running: true
        onTriggered: controlBarVisible = false
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        // --- Left Panel: Video & Controls ---
        Item {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 400

            Rectangle {
                anchors.fill: parent
                color: "black"

                HoverHandler {
                    id: videoHover
                    onPointChanged: {
                        window.controlBarVisible = true
                        hideControlsTimer.restart()
                    }
                }

                MediaPlayer {
                        id: player
                        source: backend.currentVideoUrl
                        audioOutput: AudioOutput {}
                        videoOutput: videoOutput
                        
                        onPositionChanged: {
                            if (!progressSlider.pressed) {
                                progressSlider.value = player.position
                            }
                            backend.updateSubtitle(player.position)
                        }
                        onDurationChanged: {
                            progressSlider.to = player.duration
                        }
                    }

                    VideoOutput {
                        id: videoOutput
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectFit
                    }

                    // Native, perfect Subtitle Overlay!
                    Rectangle {
                        id: subtitleOverlay
                        visible: backend.currentSubtitleText !== ""
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: window.controlBarVisible ? 90 : 30
                        Behavior on anchors.bottomMargin { NumberAnimation { duration: 300 } }
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(subtitleText.paintedWidth + 40, parent.width - 40)
                        height: subtitleText.paintedHeight + 20
                        color: Qt.rgba(0.2, 0.2, 0.2, 0.7)
                        radius: 8

                        Text {
                            id: subtitleText
                            anchors.centerIn: parent
                            text: backend.currentSubtitleText
                            color: "white"
                            font.pixelSize: 24
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            width: parent.width - 40
                        }
                    }

                // Controls Area
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 60
                    color: Qt.rgba(0.145, 0.145, 0.149, 0.85) // Transparent dark background
                    border.color: "#333333"
                    border.width: 1
                    opacity: window.controlBarVisible ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    HoverHandler {
                        id: controlsHover
                        onHoveredChanged: {
                            if (hovered) {
                                window.controlBarVisible = true
                                hideControlsTimer.stop()
                            } else {
                                hideControlsTimer.restart()
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15

                        Button {
                            text: player.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶"
                            font.pixelSize: 20
                            onClicked: {
                                if (player.playbackState === MediaPlayer.PlayingState)
                                    player.pause()
                                else
                                    player.play()
                            }
                        }

                        Slider {
                            id: progressSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 0
                            value: 0
                            onMoved: player.position = value
                        }

                        Text {
                            text: formatTime(player.position) + " / " + formatTime(player.duration)
                            color: "#cccccc"
                        }

                        ComboBox {
                            model: ["1.0x", "1.5x", "2.0x", "2.5x", "3.0x"]
                            onCurrentTextChanged: {
                                let match = currentText.match(/(\d+\.\d+)/);
                                if (match) {
                                    player.playbackRate = parseFloat(match[1]);
                                }
                            }
                        }

                        Button {
                            text: "📂"
                            font.pixelSize: 20
                            onClicked: fileDialog.open()
                        }

                        Button {
                            text: window.rightPanelVisible ? "⯈" : "⯇"
                            font.pixelSize: 20
                            onClicked: window.rightPanelVisible = !window.rightPanelVisible
                        }
                    }
                }
            }
        }

        // --- Right Panel: Subtitles & Playlist ---
        Item {
            visible: window.rightPanelVisible
            SplitView.preferredWidth: 400
            SplitView.minimumWidth: 200

            SplitView {
                anchors.fill: parent
                orientation: Qt.Vertical

                // Subtitles List
                Rectangle {
                    SplitView.fillHeight: true
                    color: "#252526"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            color: "#333333"
                            Text {
                                text: "Subtitles"
                                color: "white"
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                            }
                        }

                        ListView {
                            id: subtitlesListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: subtitleModel
                            clip: true

                            delegate: Rectangle {
                                width: ListView.view.width
                                height: subText.paintedHeight + 20
                                color: index === backend.activeSubtitleIndex ? "#007acc" : 
                                       mouseAreaSub.containsMouse ? "#37373d" : "transparent"

                                Text {
                                    id: subText
                                    text: model.text
                                    color: "white"
                                    width: parent.width - 20
                                    wrapMode: Text.WordWrap
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: mouseAreaSub
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        player.position = model.start
                                    }
                                }
                            }

                            // Auto-scroll logic
                            Connections {
                                target: backend
                                function onActiveSubtitleIndexChanged() {
                                    if (player.playbackState === MediaPlayer.PlayingState) {
                                        // Simple auto-scroll for now
                                        subtitlesListView.positionViewAtIndex(backend.activeSubtitleIndex, ListView.Center)
                                    }
                                }
                            }
                        }
                    }
                }

                // Playlist
                Rectangle {
                    SplitView.preferredHeight: 300
                    color: "#252526"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            color: "#333333"
                            Text {
                                text: "Playlist"
                                color: "white"
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: playlistModel
                            clip: true

                            delegate: Rectangle {
                                width: ListView.view.width
                                height: 40
                                color: ("file://" + model.path) === backend.currentVideoUrl.toString() ? "#007acc" : 
                                       mouseAreaPlay.containsMouse ? "#37373d" : "transparent"

                                Text {
                                    text: model.name
                                    color: "white"
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                }

                                MouseArea {
                                    id: mouseAreaPlay
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onDoubleClicked: {
                                        backend.loadVideo(model.path)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Helper functions
    function formatTime(ms) {
        let totalSeconds = Math.floor(ms / 1000);
        let hours = Math.floor(totalSeconds / 3600);
        let minutes = Math.floor((totalSeconds % 3600) / 60);
        let seconds = totalSeconds % 60;
        
        return hours.toString().padStart(2, '0') + ':' + 
               minutes.toString().padStart(2, '0') + ':' + 
               seconds.toString().padStart(2, '0');
    }

    // File Dialog Component Placeholder 
    FileDialog {
        id: fileDialog
        title: "Please choose a video file"
        nameFilters: ["Video files (*.mp4 *.mkv *.avi *.webm)"]
        onAccepted: {
            backend.loadVideo(fileDialog.selectedFile.toString())
        }
    }
}
