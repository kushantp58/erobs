# MTC GUI

PyQt6-based GUI for creating and executing robot tasks via the beambot orchestrator.

## Modules

| File | Purpose |
|------|---------|
| `main.py` | Entry point, dark theme setup |
| `main_window.py` | QMainWindow — task tree, toolbar, splitter layout |
| `ros2_bridge.py` | The GUI's ROS thread: spins a ROS node on a background thread and hands updates to the GUI thread with pyqtSignal |
| `task_forms.py` | One dialog per task step type (moveto, pick/place sample, tool exchange, etc.) |
| `camera_panel.py` | Camera display with ArUco marker and contour overlays |
| `chat_panel.py` | LLM chat panel with message bubbles |
| `agent_bridge.py` | The GUI's agent thread: runs the RobotAgent on a background thread so the GUI does not block |
| `agent_modes.py` | Plan and Run modes for the chat panel agent |
| `pose_dialogs.py` | Pose editor, manager, and save dialogs |
| `pose_io.py` | Reads and writes the poses file |
| `poses_panel.py` | Filterable list of saved poses |
| `step_list_panel.py` | Step-by-step progress of a running task script |
| `visualization_panel.py` | 3D robot view |
| `theme.py` | Shared colors, fonts and Qt styles |

## Usage

```bash
# Via launch file
ros2 launch beambot_gui beambot_gui_client.launch.py

# Direct
ros2 run beambot_gui beambot_gui_client
```

## Dependencies

- `python3-pyqt6`, `python3-pyqt6.qtwebengine`
- `rclpy`
- `beambot` (action servers, agent)

## Building

```bash
colcon build --packages-select beambot_gui
```
