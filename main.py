import sys
import os
import time
from PySide6.QtCore import Qt, QUrl, QTimer, QObject, Slot, Signal, Property, QAbstractListModel, QModelIndex, QByteArray
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from subtitle_parser import parse_subtitle

class PlaylistModel(QAbstractListModel):
    NameRole = Qt.ItemDataRole.UserRole + 1
    PathRole = Qt.ItemDataRole.UserRole + 2

    def __init__(self, parent=None):
        super().__init__(parent)
        self._playlist = []

    def rowCount(self, parent=QModelIndex()):
        return len(self._playlist)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid():
            return None
        if 0 <= index.row() < self.rowCount():
            item = self._playlist[index.row()]
            if role == self.NameRole:
                return item['name']
            elif role == self.PathRole:
                return item['path']
        return None

    def roleNames(self):
        return {
            self.NameRole: QByteArray(b"name"),
            self.PathRole: QByteArray(b"path")
        }

    def load_directory(self, directory):
        self.beginResetModel()
        self._playlist.clear()
        video_extensions = ('.mp4', '.mkv', '.avi', '.webm')
        try:
            files = [f for f in os.listdir(directory) if f.lower().endswith(video_extensions)]
            files.sort()
            for file in files:
                self._playlist.append({
                    "name": file,
                    "path": os.path.join(directory, file)
                })
        except FileNotFoundError:
            pass
        self.endResetModel()

class SubtitleModel(QAbstractListModel):
    TextRole = Qt.ItemDataRole.UserRole + 1
    StartRole = Qt.ItemDataRole.UserRole + 2
    EndRole = Qt.ItemDataRole.UserRole + 3

    def __init__(self, parent=None):
        super().__init__(parent)
        self._subtitles = []

    def rowCount(self, parent=QModelIndex()):
        return len(self._subtitles)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid():
            return None
        if 0 <= index.row() < self.rowCount():
            item = self._subtitles[index.row()]
            if role == self.TextRole:
                return item['text'].strip()
            elif role == self.StartRole:
                return item['start']
            elif role == self.EndRole:
                return item['end']
        return None

    def roleNames(self):
        return {
            self.TextRole: QByteArray(b"text"),
            self.StartRole: QByteArray(b"start"),
            self.EndRole: QByteArray(b"end")
        }

    def load_subtitles(self, filepath):
        self.beginResetModel()
        self._subtitles.clear()
        
        base_name = os.path.splitext(filepath)[0]
        sub_path = None
        for ext in ['.srt', '.vtt']:
            if os.path.exists(base_name + ext):
                sub_path = base_name + ext
                break
                
        if sub_path:
            self._subtitles = parse_subtitle(sub_path)
            
        self.endResetModel()
        return len(self._subtitles) > 0

    def get_subtitle_at(self, position_ms):
        # Could be binary search for large files, but linear is fine for normal subs
        for i, sub in enumerate(self._subtitles):
            if sub["start"] <= position_ms <= sub["end"]:
                return sub["text"].strip(), i
        return "", -1

class PlayerBackend(QObject):
    # Signals to update QML
    currentVideoUrlChanged = Signal()
    currentSubtitleTextChanged = Signal()
    activeSubtitleIndexChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._currentVideoUrl = QUrl()
        self._currentSubtitleText = ""
        self._activeSubtitleIndex = -1
        
        self.playlistModel = PlaylistModel(self)
        self.subtitleModel = SubtitleModel(self)

    # --- Properties ---
    @Property(QUrl, notify=currentVideoUrlChanged)
    def currentVideoUrl(self):
        return self._currentVideoUrl

    @Property(str, notify=currentSubtitleTextChanged)
    def currentSubtitleText(self):
        return self._currentSubtitleText

    @Property(int, notify=activeSubtitleIndexChanged)
    def activeSubtitleIndex(self):
        return self._activeSubtitleIndex

    # --- Slots callable from QML ---
    @Slot(str)
    def loadVideo(self, filepath):
        if filepath.startswith("file://"):
            filepath = filepath[7:] # Remove file:// prefix for local OS checks
            
        self._currentVideoUrl = QUrl.fromLocalFile(filepath)
        self.currentVideoUrlChanged.emit()
        
        # Load associated directories into models
        directory = os.path.dirname(filepath)
        self.playlistModel.load_directory(directory)
        self.subtitleModel.load_subtitles(filepath)
        
        # Reset current subtitle
        self.updateSubtitle(0)

    @Slot(int)
    def updateSubtitle(self, position_ms):
        text, index = self.subtitleModel.get_subtitle_at(position_ms)
        
        if self._currentSubtitleText != text:
            self._currentSubtitleText = text
            self.currentSubtitleTextChanged.emit()
            
        if self._activeSubtitleIndex != index:
            self._activeSubtitleIndex = index
            self.activeSubtitleIndexChanged.emit()

import json

class ConfigManager(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")
        self._config = {
            "windowWidth": 1200,
            "windowHeight": 800,
            "rightPanelWidth": 400,
            "subtitlesHeight": 400
        }
        self.load()

    def load(self):
        if os.path.exists(self.config_path):
            try:
                with open(self.config_path, 'r') as f:
                    self._config.update(json.load(f))
            except Exception:
                pass

    def save(self):
        try:
            with open(self.config_path, 'w') as f:
                json.dump(self._config, f, indent=4)
        except Exception:
            pass

    windowWidthChanged = Signal()
    windowHeightChanged = Signal()
    rightPanelWidthChanged = Signal()
    subtitlesHeightChanged = Signal()

    @Property(int, notify=windowWidthChanged)
    def windowWidth(self):
        return self._config.get("windowWidth", 1200)

    @windowWidth.setter
    def windowWidth(self, v):
        self._config["windowWidth"] = v
        self.save()
        self.windowWidthChanged.emit()

    @Property(int, notify=windowHeightChanged)
    def windowHeight(self):
        return self._config.get("windowHeight", 800)

    @windowHeight.setter
    def windowHeight(self, v):
        self._config["windowHeight"] = v
        self.save()
        self.windowHeightChanged.emit()

    @Property(int, notify=rightPanelWidthChanged)
    def rightPanelWidth(self):
        return self._config.get("rightPanelWidth", 400)

    @rightPanelWidth.setter
    def rightPanelWidth(self, v):
        self._config["rightPanelWidth"] = v
        self.save()
        self.rightPanelWidthChanged.emit()

    @Property(int, notify=subtitlesHeightChanged)
    def subtitlesHeight(self):
        return self._config.get("subtitlesHeight", 400)

    @subtitlesHeight.setter
    def subtitlesHeight(self, v):
        self._config["subtitlesHeight"] = v
        self.save()
        self.subtitlesHeightChanged.emit()


if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    
    # We use QQmlApplicationEngine to load the heavily aesthetic QML UI
    engine = QQmlApplicationEngine()
    
    # Instantiate our python backend controller
    backend = PlayerBackend()
    config = ConfigManager()
    
    # Expose the backend and models to the QML context
    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("playlistModel", backend.playlistModel)
    engine.rootContext().setContextProperty("subtitleModel", backend.subtitleModel)
    engine.rootContext().setContextProperty("config", config)
    
    # Load the main.qml file which we are about to create
    qml_file = os.path.join(os.path.dirname(__file__), "main.qml")
    engine.load(QUrl.fromLocalFile(qml_file))
    
    if not engine.rootObjects():
        sys.exit(-1)
        
    sys.exit(app.exec())
