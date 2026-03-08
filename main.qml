import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Dialogs

ApplicationWindow {
    id: window
    visible: true
    width: config.windowWidth
    height: config.windowHeight
    title: "MeowPot"
    color: "#1e1e1e"

    onClosing: {
        config.windowWidth = window.width;
        config.windowHeight = window.height;
        config.rightPanelWidth = rightPanel.SplitView.preferredWidth;
        config.subtitlesHeight = subtitlesPanel.SplitView.preferredHeight;
    }

    // Material theme settings natively available in QML
    Material.theme: Material.Dark
    Material.accent: Material.LightBlue

    property bool rightPanelVisible: true
    property bool controlBarVisible: true

    Item {
        id: hotkeyHandler
        anchors.fill: parent
        focus: true

        property bool rightPressed: false
        property bool leftPressed: false
        property real activeSpeed: parseFloat(speedCombo.currentText)

        Keys.onSpacePressed: (event) => {
            if (player.playbackState === MediaPlayer.PlayingState) player.pause();
            else player.play();
            event.accepted = true;
        }

        Keys.onPressed: (event) => {
            if (event.isAutoRepeat) { event.accepted = true; return; }
            if (event.key === Qt.Key_Right) {
                hotkeyHandler.rightPressed = true;
                fastForwardTimer.start();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                hotkeyHandler.leftPressed = true;
                fastBackwardTimer.start();
                event.accepted = true;
            }
        }

        Keys.onReleased: (event) => {
            if (event.isAutoRepeat) { event.accepted = true; return; }
            if (event.key === Qt.Key_Right) {
                fastForwardTimer.stop();
                if (hotkeyHandler.rightPressed) {
                    hotkeyHandler.rightPressed = false;
                    if (player.playbackRate > hotkeyHandler.activeSpeed + 1.0) {
                        player.playbackRate = hotkeyHandler.activeSpeed;
                    } else {
                        player.position = Math.min(player.position + 10000, player.duration);
                    }
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                fastBackwardTimer.stop();
                if (hotkeyHandler.leftPressed) {
                    hotkeyHandler.leftPressed = false;
                    if (player.playbackRate !== hotkeyHandler.activeSpeed) {
                        player.playbackRate = hotkeyHandler.activeSpeed;
                    } else {
                        player.position = Math.max(0, player.position - 10000);
                    }
                }
                event.accepted = true;
            }
        }

        Timer {
            id: fastForwardTimer
            interval: 300
            onTriggered: {
                if (hotkeyHandler.rightPressed) player.playbackRate = hotkeyHandler.activeSpeed + 2.0;
            }
        }

        Timer {
            id: fastBackwardTimer
            interval: 300
            onTriggered: {
                if (hotkeyHandler.leftPressed) player.playbackRate = -(hotkeyHandler.activeSpeed + 2.0);
            }
        }
    }

    Timer {
        id: hideControlsTimer
        interval: 2000
        running: true
        onTriggered: {
            if (controlBarHover.hovered) {
                hideControlsTimer.restart()
            } else {
                controlBarVisible = false
            }
        }
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
                    property point lastPos: Qt.point(-1, -1)
                    onPointChanged: {
                        if (Math.abs(point.position.x - lastPos.x) < 1 && Math.abs(point.position.y - lastPos.y) < 1) return;
                        lastPos = point.position;
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
                        id: controlBarHover
                        property point lastPos: Qt.point(-1, -1)
                        onPointChanged: {
                            if (Math.abs(point.position.x - lastPos.x) < 1 && Math.abs(point.position.y - lastPos.y) < 1) return;
                            lastPos = point.position;
                            window.controlBarVisible = true
                            hideControlsTimer.restart()
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15

                        Button {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            focusPolicy: Qt.NoFocus
                            padding: 0
                            onClicked: {
                                if (player.playbackState === MediaPlayer.PlayingState)
                                    player.pause()
                                else
                                    player.play()
                            }
                            contentItem: Item {
                                anchors.fill: parent
                                Component.onCompleted: {
                                    if (player.playbackState === MediaPlayer.PlayingState) pauseRects.visible = true
                                    else playCanvas.visible = true
                                }
                                Connections {
                                    target: player
                                    function onPlaybackStateChanged() {
                                        if (player.playbackState === MediaPlayer.PlayingState) {
                                            pauseRects.visible = true; playCanvas.visible = false;
                                        } else {
                                            pauseRects.visible = false; playCanvas.visible = true;
                                        }
                                    }
                                }
                                Canvas {
                                    id: playCanvas
                                    anchors.fill: parent
                                    visible: false
                                    onPaint: {
                                        var ctx = getContext("2d"); ctx.fillStyle = "white"; ctx.beginPath();
                                        ctx.moveTo(10, 8); ctx.lineTo(24, 16); ctx.lineTo(10, 24); ctx.fill();
                                    }
                                }
                                Row {
                                    id: pauseRects
                                    anchors.centerIn: parent
                                    spacing: 4
                                    visible: false
                                    Rectangle { width: 4; height: 16; color: "white" }
                                    Rectangle { width: 4; height: 16; color: "white" }
                                }
                            }
                        }

                        Slider {
                            id: progressSlider
                            focusPolicy: Qt.NoFocus
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
                            id: speedCombo
                            focusPolicy: Qt.NoFocus
                            model: ["1.0x", "1.5x", "2.0x", "2.5x", "3.0x"]
                            onCurrentTextChanged: {
                                let match = currentText.match(/(\d+\.\d+)/);
                                if (match && !hotkeyHandler.rightPressed && !hotkeyHandler.leftPressed) {
                                    player.playbackRate = parseFloat(match[1]);
                                }
                            }
                        }

                        Button {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            focusPolicy: Qt.NoFocus
                            padding: 0
                            onClicked: fileDialog.open()
                            contentItem: Item {
                                anchors.fill: parent
                                Rectangle { x: 6; y: 8; width: 8; height: 3; color: "white"; radius: 1 }
                                Rectangle { x: 6; y: 10; width: 20; height: 14; color: "white"; radius: 2 }
                            }
                        }

                        Button {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            focusPolicy: Qt.NoFocus
                            padding: 0
                            onClicked: window.rightPanelVisible = !window.rightPanelVisible
                            contentItem: Canvas {
                                id: toggleRightPanelCanvas
                                anchors.fill: parent
                                Connections {
                                    target: window
                                    function onRightPanelVisibleChanged() { toggleRightPanelCanvas.requestPaint() }
                                }
                                onPaint: {
                                    var ctx = getContext("2d"); ctx.clearRect(0,0,width,height); ctx.fillStyle = "white"; ctx.beginPath();
                                    if (window.rightPanelVisible) {
                                        ctx.moveTo(20, 10); ctx.lineTo(12, 16); ctx.lineTo(20, 22);
                                    } else {
                                        ctx.moveTo(12, 10); ctx.lineTo(20, 16); ctx.lineTo(12, 22);
                                    }
                                    ctx.fill()
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Right Panel: Subtitles & Playlist ---
        Item {
            id: rightPanel
            visible: window.rightPanelVisible
            SplitView.preferredWidth: config.rightPanelWidth ? config.rightPanelWidth : 400
            SplitView.minimumWidth: 200

            SplitView {
                anchors.fill: parent
                orientation: Qt.Vertical

                // Subtitles List
                Rectangle {
                    id: subtitlesPanel
                    SplitView.fillHeight: true
                    SplitView.preferredHeight: config.subtitlesHeight ? config.subtitlesHeight : 400
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
                            focus: false
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
                                        // Bring focus back to hotkey handler after click
                                        hotkeyHandler.forceActiveFocus()
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
                            focus: false
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
                                        hotkeyHandler.forceActiveFocus()
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
