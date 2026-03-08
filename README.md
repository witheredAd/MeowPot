# MeowPot 🐾

> A modern, sleek, and subtitle-first local video player built with Python, PySide6, and QML. (一个基于 Python、PySide6 和 QML 构建的现代化、美观且字幕优先的本地视频播放器。)

> [!Warning]
> This app is vibe-built. The app itself is usable now, but this `README.md` needs review.
> 
> 该软件是 Vibe-Coding 完成的，其已可使用，但描述文件尚待检查。

MeowPot is a beautiful and modern local video player highlighting a sleek "liquid glass"-inspired dark UI, built-in subtitle parsing, state persistence, and native keyboard hotkeys.

## ✨ Features

- **Modern & Aesthetic UI**: A floating dark control bar, modern flat icons, and seamless QML Material Design integration.
- **Subtitle Integration**: A dedicated, auto-scrolling right-side panel for subtitles (`.srt`, `.vtt`) and a native video subtitle overlay.
- **Smart Playlist**: Automatically discovers and lists other video files (`.mp4`, `.mkv`, `.avi`, `.webm`) in the same directory as your playing video.
- **State Persistence**: Remembers your window size, panel proportions, playback position, and the last played video path across sessions automatically.
- **Advanced Hotkeys**: 
  - `Space` to Play/Pause.
  - `Left` / `Right` arrows to seek.
  - [ ] Hold `Left` / `Right` arrows for dynamic fast-forward and fast-backward playback speeds. (Not implemented yet)

## 🛠️ Requirements

- Python 3.8+
- [PySide6](https://pypi.org/project/PySide6/) (Qt for Python)

## 🚀 Getting Started

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/meowpot.git
   cd meowpot
   ```

2. Install the required dependencies:
   ```bash
   pip install PySide6
   ```

   or uv:
   ```bash
   uv sync
   ```

4. Run the application:
   ```bash
   python main.py
   ```
   
   or uv:
   ```bash
   uv run main.py
   ```

## 🎮 Usage

- Click the **Folder** icon on the floating control bar to open a video file.
- Toggle the **Playlist** icon to show/hide the directory playlist.
- Toggle the **Right Panel** icon to show/hide the subtitles and playlist sidebar.
- Adjust the playback speed from the dropdown available in the control bar.
