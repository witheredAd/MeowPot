import sys
import os
from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout,
                               QHBoxLayout, QPushButton, QSlider, QLabel, QSplitter,
                               QListWidget, QListWidgetItem, QFileDialog)
from PySide6.QtMultimedia import QMediaPlayer, QAudioOutput
from PySide6.QtMultimediaWidgets import QVideoWidget
from PySide6.QtCore import Qt, QUrl, QTimer

from subtitle_parser import parse_subtitle

class VideoPlayerWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Local Video Player")
        self.resize(1200, 800)
        
        # Core Media Components
        self.media_player = QMediaPlayer()
        self.audio_output = QAudioOutput()
        self.media_player.setAudioOutput(self.audio_output)
        self.video_widget = QVideoWidget()
        self.media_player.setVideoOutput(self.video_widget)
        
        # State variables
        self.current_subtitles = []
        self.current_video_dir = ""
        self.is_fullscreen = False
        
        self._setup_ui()
        self._connect_signals()
        
        # Timer for subtitle sync
        self.subtitle_timer = QTimer(self)
        self.subtitle_timer.setInterval(100)
        self.subtitle_timer.timeout.connect(self._sync_subtitle)
        
    def _setup_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        main_layout = QHBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        self.main_splitter = QSplitter(Qt.Horizontal)
        main_layout.addWidget(self.main_splitter)
        
        # --- Left Panel (Video & Controls) ---
        self.left_panel = QWidget()
        left_layout = QVBoxLayout(self.left_panel)
        left_layout.setContentsMargins(0, 0, 0, 0)
        
        # Video area
        left_layout.addWidget(self.video_widget, stretch=1)
        
        # Subtitle overlay label
        self.subtitle_label = QLabel("")
        self.subtitle_label.setAlignment(Qt.AlignCenter)
        self.subtitle_label.setStyleSheet("color: white; background-color: rgba(0, 0, 0, 150); font-size: 24px; padding: 10px;")
        self.subtitle_label.setWordWrap(True)
        self.subtitle_label.hide()
        left_layout.addWidget(self.subtitle_label)
        
        # Controls area
        self.controls_widget = QWidget()
        controls_layout = QHBoxLayout(self.controls_widget)
        controls_layout.setContentsMargins(5, 5, 5, 5)
        
        self.btn_play_pause = QPushButton("Play")
        controls_layout.addWidget(self.btn_play_pause)
        
        self.slider_progress = QSlider(Qt.Horizontal)
        self.slider_progress.setRange(0, 0)
        controls_layout.addWidget(self.slider_progress)
        
        self.label_time = QLabel("00:00:00 / 00:00:00")
        controls_layout.addWidget(self.label_time)
        
        self.btn_fullscreen = QPushButton("Fullscreen")
        controls_layout.addWidget(self.btn_fullscreen)
        
        self.btn_open = QPushButton("Open File")
        controls_layout.addWidget(self.btn_open)

        self.btn_toggle_playlist = QPushButton("Toggle Playlist")
        controls_layout.addWidget(self.btn_toggle_playlist)
        
        left_layout.addWidget(self.controls_widget)
        
        self.main_splitter.addWidget(self.left_panel)
        
        # --- Right Panel (Playlist & Subtitles) ---
        self.right_panel = QWidget()
        right_layout = QVBoxLayout(self.right_panel)
        right_layout.setContentsMargins(0, 0, 0, 0)
        
        self.right_splitter = QSplitter(Qt.Vertical)
        right_layout.addWidget(self.right_splitter)
        
        # Subtitles List
        sub_container = QWidget()
        sub_layout = QVBoxLayout(sub_container)
        sub_layout.setContentsMargins(0, 0, 0, 0)
        sub_layout.addWidget(QLabel(" Subtitles"))
        self.list_subtitles = QListWidget()
        self.list_subtitles.setWordWrap(True)
        sub_layout.addWidget(self.list_subtitles)
        self.right_splitter.addWidget(sub_container)
        
        # Playlist List
        playlist_container = QWidget()
        playlist_layout = QVBoxLayout(playlist_container)
        playlist_layout.setContentsMargins(0, 0, 0, 0)
        playlist_layout.addWidget(QLabel(" Playlist"))
        self.list_playlist = QListWidget()
        playlist_layout.addWidget(self.list_playlist)
        self.right_splitter.addWidget(playlist_container)
        
        self.main_splitter.addWidget(self.right_panel)
        self.main_splitter.setSizes([800, 400])
        self.right_splitter.setSizes([400, 400])

    def _connect_signals(self):
        self.btn_open.clicked.connect(self.open_file)
        self.btn_play_pause.clicked.connect(self.toggle_playback)
        self.btn_fullscreen.clicked.connect(self.toggle_fullscreen)
        self.btn_toggle_playlist.clicked.connect(self.toggle_right_panel)
        
        self.media_player.positionChanged.connect(self.position_changed)
        self.media_player.durationChanged.connect(self.duration_changed)
        self.media_player.playbackStateChanged.connect(self.playback_state_changed)
        
        self.slider_progress.sliderMoved.connect(self.set_position)
        
        self.list_playlist.itemDoubleClicked.connect(self.playlist_item_double_clicked)
        self.list_subtitles.itemClicked.connect(self.subtitle_item_clicked)
        
    def open_file(self):
        file_dialog = QFileDialog()
        file_path, _ = file_dialog.getOpenFileName(self, "Open Video", "", "Video Files (*.mp4 *.mkv *.avi *.webm)")
        if file_path:
            self.load_video(file_path)

    def load_video(self, file_path):
        self.media_player.setSource(QUrl.fromLocalFile(file_path))
        self.current_video_dir = os.path.dirname(file_path)
        
        self._load_playlist(self.current_video_dir, file_path)
        self._load_subtitles(file_path)
        
        self.btn_play_pause.setText("Pause")
        self.media_player.play()
        self.subtitle_timer.start()

    def _load_playlist(self, directory, current_file):
        self.list_playlist.clear()
        video_extensions = ('.mp4', '.mkv', '.avi', '.webm')
        files = [f for f in os.listdir(directory) if f.lower().endswith(video_extensions)]
        files.sort()
        
        for file in files:
            item = QListWidgetItem(file)
            item.setData(Qt.UserRole, os.path.join(directory, file))
            self.list_playlist.addItem(item)
            if os.path.join(directory, file) == current_file:
                item.setSelected(True)

    def _load_subtitles(self, video_path):
        self.current_subtitles = []
        self.list_subtitles.clear()
        self.subtitle_label.hide()
        
        base_name = os.path.splitext(video_path)[0]
        # Try finding subtitle
        sub_path = None
        for ext in ['.srt', '.vtt']:
            if os.path.exists(base_name + ext):
                sub_path = base_name + ext
                break
        
        if sub_path:
            self.current_subtitles = parse_subtitle(sub_path)
            for i, sub in enumerate(self.current_subtitles):
                item = QListWidgetItem(sub["text"].strip())
                item.setData(Qt.UserRole, sub["start"])
                item.setData(Qt.UserRole + 1, i) # Store index for sync
                self.list_subtitles.addItem(item)
    
    def playlist_item_double_clicked(self, item):
        file_path = item.data(Qt.UserRole)
        self.load_video(file_path)
        
    def subtitle_item_clicked(self, item):
        start_ms = item.data(Qt.UserRole)
        self.media_player.setPosition(start_ms)
        
    def toggle_playback(self):
        if self.media_player.playbackState() == QMediaPlayer.PlayingState:
            self.media_player.pause()
        else:
            self.media_player.play()

    def playback_state_changed(self, state):
        if state == QMediaPlayer.PlayingState:
            self.btn_play_pause.setText("Pause")
        else:
            self.btn_play_pause.setText("Play")
            
    def position_changed(self, position):
        if not self.slider_progress.isSliderDown():
            self.slider_progress.setValue(position)
        self.update_time_label()
        
    def duration_changed(self, duration):
        self.slider_progress.setRange(0, duration)
        self.update_time_label()
        
    def set_position(self, position):
        self.media_player.setPosition(position)
        
    def update_time_label(self):
        def format_ms(ms):
            s = (ms // 1000) % 60
            m = (ms // 60000) % 60
            h = (ms // 3600000)
            return f"{h:02d}:{m:02d}:{s:02d}"
        
        pos = self.media_player.position()
        dur = self.media_player.duration()
        self.label_time.setText(f"{format_ms(pos)} / {format_ms(dur)}")

    def _sync_subtitle(self):
        if not self.current_subtitles:
            self.subtitle_label.hide()
            return

        pos = self.media_player.position()
        
        active_sub = None
        active_index = -1
        # To avoid lag, binary search could be better, but linear is fine for < 5000 items
        for i, sub in enumerate(self.current_subtitles):
            if sub["start"] <= pos <= sub["end"]:
                active_sub = sub
                active_index = i
                break
        
        if active_sub:
            self.subtitle_label.setText(active_sub["text"].strip())
            self.subtitle_label.show()
            
            if active_index != -1:
                item = self.list_subtitles.item(active_index)
                if item:
                    # Scroll minimally to keep item in view
                    # We can use ensureWidgetVisible or similar, scrollToItem handles it well if we don't force too much
                    # For a smoother experience, only scroll if it's out of view, QListWidget handles it
                    self.list_subtitles.scrollToItem(item)
                    for i in range(self.list_subtitles.count()):
                        list_item = self.list_subtitles.item(i)
                        if i == active_index:
                            list_item.setBackground(Qt.darkGray)
                            list_item.setForeground(Qt.white)
                        else:
                            list_item.setBackground(Qt.transparent)
                            list_item.setForeground(Qt.white) # keep simple contrast
        else:
            self.subtitle_label.hide()
            for i in range(self.list_subtitles.count()):
                self.list_subtitles.item(i).setBackground(Qt.transparent)
                self.list_subtitles.item(i).setForeground(Qt.white)
            
    def toggle_fullscreen(self):
        if not self.is_fullscreen:
            self.showFullScreen()
            self.right_panel.hide()
            self.controls_widget.hide()
            self.is_fullscreen = True
        else:
            self.showNormal()
            self.right_panel.show()
            self.controls_widget.show()
            self.is_fullscreen = False

    def toggle_right_panel(self):
        if self.right_panel.isVisible():
            self.right_panel.hide()
        else:
            self.right_panel.show()

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape and self.is_fullscreen:
            self.toggle_fullscreen()
        elif event.key() == Qt.Key_Space:
            self.toggle_playback()
        super().keyPressEvent(event)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    
    # Simple dark mode palette for better viewing
    from PySide6.QtGui import QPalette, QColor
    dark_palette = QPalette()
    dark_palette.setColor(QPalette.Window, QColor(53, 53, 53))
    dark_palette.setColor(QPalette.WindowText, Qt.white)
    dark_palette.setColor(QPalette.Base, QColor(25, 25, 25))
    dark_palette.setColor(QPalette.AlternateBase, QColor(53, 53, 53))
    dark_palette.setColor(QPalette.ToolTipBase, Qt.white)
    dark_palette.setColor(QPalette.ToolTipText, Qt.white)
    dark_palette.setColor(QPalette.Text, Qt.white)
    dark_palette.setColor(QPalette.Button, QColor(53, 53, 53))
    dark_palette.setColor(QPalette.ButtonText, Qt.white)
    dark_palette.setColor(QPalette.BrightText, Qt.red)
    dark_palette.setColor(QPalette.Link, QColor(42, 130, 218))
    dark_palette.setColor(QPalette.Highlight, QColor(42, 130, 218))
    dark_palette.setColor(QPalette.HighlightedText, Qt.black)
    app.setPalette(dark_palette)
    
    window = VideoPlayerWindow()
    window.show()
    sys.exit(app.exec())
