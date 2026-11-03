# Glossary

Names as they exist in the repo. "Proposed" marks where the current name is
ambiguous and a rename or a fixed convention is suggested. Items marked
`<FILL IN: ...>` are not verifiable from the code and need a human answer.

## Naming collisions to resolve

| Term | What it is used for | Proposed |
| --- | --- | --- |
| erobs | The repository / project name | Keep for the repo only. |
| beambot | The ROS 2 package, the launch file, the config env var prefix, the action names (`/beambot_execution`) | Keep for the ROS software stack. |
| orchestrator | ROS node `beambot_orchestrator` that serves `/beambot_execution` | Keep; always say "orchestrator node". |
| bridge | Six unrelated things in the code: the rosbridge gateway (a network-facing WebSocket gateway), `cv_bridge` (an image conversion library, not a network bridge), the MCP server's ROS node (`beambot_mcp_bridge`), the MCP server's `ROS2Bridge` class, the GUI's `ROS2Bridge` class, the GUI's `AgentBridge` class | Avoid "bridge" alone. Use it only inside a class or node name, or as "rosbridge gateway". See the "bridge" row under Overloaded words. |
| MCP server | Python process exposing robot MCP tools to an LLM agent. It also runs its own ROS node, `beambot_mcp_bridge`. It is not rosbridge. | Keep; it is a ROS client (not a rosbridge client) and not part of the robot stack. Its MCP client is the robot agent. |

## ROS terms for non-ROS readers

ROS 2 (Robot Operating System) is a set of libraries for building robot software out of
many small programs that talk to each other. In this project "ROS" always means ROS 2
Jazzy, a specific release. (`humble` is an older release and also the name of this
repo's default git branch: it does not mean the code is for Humble.)

| Term | Plain meaning | Example here |
| --- | --- | --- |
| Node | One running ROS program. Not a computer. | `beambot_orchestrator` |
| Package | A folder of code with a name that ROS can find. | `beambot`, `beambot_interfaces` |
| Launch file | A script that starts several nodes together. | `beambot_bringup.launch.py` |
| Topic | A named stream of messages. Publishers send, subscribers receive. No reply. | `/joint_states`, `/beambot/execution_state` |
| ROS service | A named request and reply: a client sends a request and gets one response. How long that takes depends on the service. Unlike a ROS action, the interface has no progress updates and no standard way to cancel a request, so use a ROS action for long-running work. Not a systemd service. | `beambot/pause`, `/dashboard_client/play` |
| ROS action | A named long-running request with progress updates and a final result, and it can be cancelled. | `beambot_execution` |
| Action server / action client | An action server is the part of a node that accepts goals for a ROS action and runs them. An action client is the part of a node that sends a goal and receives its feedback and result. One node can host action servers and use action clients at the same time. Both are programs, not machines. | The orchestrator node hosts the action server for `beambot_execution` and uses action clients for `beambot_moveto` and the other task-step ROS actions |
| ROS client | Any program that uses ROS interfaces as a caller or subscriber, through a ROS node: it sends action goals, calls ROS services or subscribes to topics. It is defined by that use, not by where it runs. It can be inside the runtime container or on another machine. | Beambot GUI (`beambot_gui_client`), Bluesky device, MCP server (`beambot_mcp_bridge`). The orchestrator is also a ROS client of the task-step action servers |
| Remote ROS client | A ROS client on a different machine from the control VM. It needs a network path to the VM and ROS discovery that works between the two machines (architecture.md, paths 6 and 7). Every ROS client, remote or not, must use the same ROS domain ID as the runtime container. | Any of the ROS clients above, run on another machine |
| Message / interface | An interface is the definition of a data format that ROS nodes use. There are three kinds: a message (`.msg`) is what a topic carries, a ROS service interface (`.srv`) defines a request and a response, and a ROS action interface (`.action`) defines a goal, feedback and a result. | `beambot_interfaces` in this repo defines only action interfaces, such as `BeambotExecution.action`. Messages and ROS service types come from upstream packages, for example `std_srvs/Trigger` |
| Parameter | A setting on a node. | `use_mock_hardware` |
| TF | The tree of coordinate frames (where each part of the robot is relative to others). | `base_link`, `flange` |
| DDS | The network layer ROS 2 uses between nodes. This project uses Fast DDS. | |
| ROS domain ID (`ROS_DOMAIN_ID`) | A number; the ROS docs suggest choosing one from 0 to 101 to stay clear of the operating system's ephemeral ports (a recommendation, not the technical limit). ROS nodes only see each other when they use the same number. Not a DNS, Windows or network domain. | Image default 0; the `pr-docker` runtime service sets 65 |
| ROS discovery | How ROS nodes find each other. Either multicast (the default) or discovery server mode, where nodes are pointed at a Fast DDS discovery server with `ROS_DISCOVERY_SERVER`. Unrelated to EPICS name search. | |
| `ros2` command | The command-line tool for listing nodes, topics and calling ROS actions. | `ros2 node list` |

## Overloaded words

Each of these means different things in this project. Docs should say which one. These
are conventions for writing docs, not rules for code: code names stay as they are.

| Word | Meanings | Convention for these docs |
| --- | --- | --- |
| server | Action server (a node), MCP server, discovery server, rosbridge, "a machine" | Avoid "server" alone: "action server", "MCP server", "discovery server", "rosbridge gateway". Say "VM" or "host" for a machine. In node and file names (`move_to_server.py`, `beambot_moveto_server`) "server" means action server. |
| client | ROS client, remote ROS client, action client inside a node, rosbridge client, MCP client (the robot agent) | "ROS client" is any program that uses ROS interfaces as a caller or subscriber, wherever it runs (see ROS terms). Say "remote ROS client" when it runs on a different machine from the control VM, "action client" for the part of a node that sends goals, "rosbridge client" for non-ROS callers of the gateway, and "MCP client" for the robot agent. Name the specific thing where possible. |
| service | ROS service, systemd service | Always write "ROS service" or "systemd service". Avoid "unit". |
| action | ROS action, a step inside a task script (`current_action` in the feedback) | Write "ROS action" (and name it, e.g. the `beambot_execution` ROS action) for the ROS mechanism. Write "task step" for a step in a task script, and "goal" for the request sent to a ROS action. |
| task | MTC task (a MoveIt Task Constructor object), the JSON task script, one item in a task script, a Bluesky plan | Avoid "task" alone. "Task script": the JSON sent in a goal. "Task step": one item in it (`moveto`, `end_effector`, ...), which the code calls a "task" (`SUPPORTED_TASK_TYPES`). "MTC task": the MoveIt object built from one or more task steps. |
| node | ROS program | Always a ROS node, never a machine: say "VM" or "host" for a machine. Write "ROS node" where the context is not already ROS (e.g. in the EPICS and deployment sections). |
| controller | The UR controller box, a `ros2_control` controller (`scaled_joint_trajectory_controller`, `gripper_action_controller`), the node `game_controller_node` | Avoid "controller" alone: "UR controller", "ros2_control controller" (or its full name). For the hand-held device write "joystick" (see below). |
| joystick | The ROS term (`joy` package, `enable_joystick`) for a hand-held input device. Here it is a gamepad, used for joystick teleop through MoveIt Servo. Off by default. | Write "joystick" for the ROS feature and argument; "gamepad" only to name the physical device. |
| bridge | rosbridge is a network-facing gateway: it accepts WebSocket connections on a port. The other uses are not network bridges: `cv_bridge` is a library that converts between ROS images and OpenCV images, and the rest are classes and a ROS node that run inside one process. | "rosbridge gateway" for the WebSocket gateway. Otherwise only inside a code name: see the list below the table. |
| domain | ROS domain ID, DDS domain (the same thing), DNS domain, network or subnet | Write "ROS domain ID" for the number. Avoid "DDS domain" or "domain" alone. For a subnet say "subnet" (see INST); for a DNS name say "hostname". |
| discovery | ROS discovery (multicast or discovery server mode), EPICS name search (Channel Access) | Write "ROS discovery" or "EPICS name search", never "discovery" alone. "Discovery server" always means the Fast DDS one; say whether it is the local-test container or a lab-hosted one. |
| pose | Joint angles, position and orientation of a frame, an entry in the saved poses file, a detected object's position and orientation | Avoid "pose" alone: see the list below the table. |
| end effector | Anything mounted on the arm: the HandE, 2FG7 and ePick grippers, or the pipettor. `none` is the config entry for no attached end effector, not a device. The code also calls it "gripper" (`current_gripper`, `grippers:` in the config, `gripper_arg`) and "tool" (`tool_exchange`). | "End effector" is the general term in these docs. Code names stay as they are. |
| gripper | A kind of end effector that grips: HandE, 2FG7, and the ePick vacuum gripper. The pipettor is not a gripper, although the code's `current_gripper` can hold it. | Say "gripper" only for those three. |
| tool | The UR controller's wrist connector (`tool_voltage`, `use_tool_communication`), the TF frame `tool0`, MCP tools, the `tool_exchange` task step | Avoid "tool" alone. Allowed: "tool port" or "tool power" (wrist connector), "tool pose" (see pose), "`tool0` frame", "MCP tool" (LLM-callable function). `tool_exchange` swaps the end effector. |
| end effector task step | The `end_effector` task step: opens, closes or otherwise actuates the attached end effector through a named MoveIt state | Always "end effector task step", never "end effector" alone for this. |
| tip | `tip_frame` (the TF frame at the end effector's working point), `pickup_tip` (a pipette tip, a consumable) | "Tip frame" or "pipette tip". Avoid "tip" alone. |
| erobs, beambot | Repo, ROS package, system | erobs is the repo. beambot is the ROS software. |
| runtime, stack | The image, the container, all nodes | "Runtime container" is the container. "Stack" is the set of nodes that run in it. MoveIt and the UR driver are part of the stack but start later (see "on demand"). |
| IOC | EPICS Input/Output Controller: a process that serves PVs, not hardware | Write "EPICS IOC". |
| MCP | Model Context Protocol: how an LLM agent calls tools. Not motion control. | Write "MCP". |
| PDF, CMS, LIX | NSLS-II beamline names, not file formats. PDF is the Pair Distribution Function beamline. | Write "the PDF beamline". |
| Hermes, AIFAPIM | `HERMES_ENDPOINT` and `AIFAPIM_API_KEY`: settings for an LLM gateway that the robot agent reaches through the Anthropic client library. Not related to the robot hardware | "LLM gateway". Keep the variable names as they are in the code. |
| on demand | Processes the orchestrator starts when it receives a goal, not with the container: MoveIt and the UR driver | "Started with the runtime container" (the bringup launch file) or "started on demand" (by the orchestrator). Say which. |
| External Control | The URCap plugin, the saved robot program that contains the External Control node, and the host address in its settings. Installing the plugin does not create or configure a program. | Say "External Control URCap" for the plugin, "External Control program" for the saved program and "External Control host address" for the VM address. See Moving parts. |
| moveto, endeffector | `move_to` / `moveto` and `end_effector` / `endeffector` are both used. The node name is the one-word form. | Node and action names use the one-word form. Python modules use underscores. |

### Bridge: what to write for each code name

- rosbridge: write "rosbridge gateway" (ROS package `rosbridge_server`). It is the only item here that listens on a network port (WebSocket, 9090).
- `cv_bridge`: write the name. It is an upstream library that converts between ROS image messages and OpenCV images. It has no network role and is unrelated to rosbridge.
- `beambot_mcp_bridge` (class `ROS2BridgeNode`): "the MCP server's ROS node".
- MCP server `ROS2Bridge`: "the MCP server's ROS thread" (starts the ROS node and spins it on a background thread).
- GUI `ROS2Bridge`: "the GUI's ROS thread" (spins a ROS node on a background thread and hands updates to the GUI thread).
- GUI `AgentBridge`: "the GUI's agent thread" (runs the robot agent on a background thread so the GUI does not block).
- Apart from rosbridge, these are not described in `architecture.md` because they never leave a process.

### Pose: what to write for each meaning

- Joint state: the arm's current joint angles (`/joint_states`, `get_robot_state`).
- Tool pose: position and orientation of the arm's tool frame (`flange` by default, or `tool0`) in `base_link`, from a frame transform (`get_tf_transform`).
- Saved pose: a named set of six joint angles in degrees from the poses file. It is not a Cartesian point, despite the name.
- Detected pose: position and orientation of a detected object in `base_link` (`detected_position`, `detected_orientation`).

## Moving parts

| Name | Kind | Where | What it does |
| --- | --- | --- | --- |
| UR arm | Hardware | Beamline | The robot arm: a UR5e (the beamline config and agent prompt use `ur5e`). |
| UR controller | Hardware | Beamline | The arm's own controller box (teach pendant included). Reached by the UR driver at `robot.ip` from the beamline config. |
| UR driver | ROS nodes (`ur_robot_driver`) | Started on demand by the orchestrator | Talks to the UR controller and exposes the arm to ROS through `ros2_control`. Not the same as the UR controller. |
| External Control URCap | Plugin (`externalcontrol-*.urcap`) | Installed on the UR controller | Adds the External Control node and its settings to the teach pendant. Installed once per robot. Installing it does not create or configure a robot program. |
| External Control program | Robot program on the UR controller | Teach pendant | A saved program that contains the External Control node. A person creates and saves it on the teach pendant. When it runs, it lets the UR driver move the arm. The orchestrator starts it by calling the `/dashboard_client/play` ROS service after each MoveIt launch. It does not create or load the program. |
| External Control host address | Setting | Teach pendant | The address of the control VM, as the UR controller sees it, from which the UR controller fetches its script (the UR driver's script port, 50002). Configured in the External Control settings on the teach pendant. Site-specific and not recorded in this repo. It is not the UR driver's `reverse_ip` setting. <FILL IN: confirm on the lab robot that the saved program exists, which VM address it holds (role only, not the address), and the PolyScope version> |
| INST | Network | Lab | Name of the lab IPv4 subnet that the control VM sits on. It is a network name, not a host. The EPICS network is a different network. Actual subnet and addressing are site-specific and kept out of the repo. <FILL IN: confirm "INST" is the name in use for this subnet. It appears nowhere else in the repo> |
| control VM | Host | Lab | VM that runs the runtime container. <FILL IN: its role name for the Ansible inventory> |
| Beamline config | YAML file | `src/beambot/config/` | Per-beamline settings, selected by `BEAMBOT_BEAMLINE_CONFIG`. `example_cms_beamline.yaml` is the template. |
| Runtime image | Container image | `docker/jazzy_runtime/` | ROS 2 Jazzy image with the workspace built. Entrypoint is `utils/start_mcp_robot_stack.sh`. |
| `erobs-jazzy-runtime.service` | systemd service | `docker/jazzy_runtime/` | Runs the runtime image with Podman on the control VM, as a system service. The container it creates is named `beambot_ros`. |
| `erobs-discovery-server.service` | systemd service | `docker/jazzy_runtime/` (`pr-docker` branch) | Runs a Fast DDS discovery server in a container named `erobs_discovery_server`. Local testing only. |
| `beambot_bringup.launch.py` | ROS launch file | `src/beambot/launch/` | Starts the nodes that run with the runtime container (see architecture.md). MoveIt and the UR driver are not started here. |
| Orchestrator | ROS node `beambot_orchestrator` | `action_servers/orchestrator.py` | Serves the `/beambot_execution` ROS action (`BeambotExecution`). Takes a task script as JSON, starts MoveIt and the UR driver if needed, runs MoveIt Task Constructor (MTC). Pause and resume ROS services. |
| Task-step action servers | ROS nodes | `action_servers/*_server.py` | `move_to`, `end_effector`, `tool_exchange`, `vision_scan`, `vision_task`, `sample_pick_place`, `pipettor`. Node names are listed in architecture.md (for example `beambot_moveto_server`). Use through the orchestrator, not directly. |
| Zivid camera node | ROS node `zivid_camera` | launch, `enable_vision` | Camera driver (package `zivid_camera`). Off by default. |
| rosbridge gateway | ROS node(s) | launch, `enable_rosbridge` | WebSocket gateway to ROS (package `rosbridge_server`, nodes `rosbridge_websocket` and `rosapi`). Lets rosbridge clients (no ROS needed) reach the stack. On by default, with no authentication or TLS. |
| MCP server | Process | `src/beambot/mcp_server/` | Exposes MCP tools (`ping`, `get_robot_state`, `stop_robot`, ...) over stdio to the robot agent, which is the MCP client. It also runs its own ROS node, `beambot_mcp_bridge`, which subscribes to topics and calls ROS services. It does not use the rosbridge gateway. The agent prompt also says a second, generic MCP server, `ros-mcp-server`, is wired, and its tools are where `send_action_goal` comes from. It is not in this repo, and the repo does not say how it reaches ROS. <FILL IN: how `ros-mcp-server` is installed and configured (the `.mcp.json` is not in the repo), and whether it reaches ROS through the rosbridge gateway or native ROS 2. Also reconcile with architecture.md, which says `beambot_mcp_bridge` sends `beambot_execution` goals while the code shows only `ros-mcp-server` does> |
| Robot agent | Process | `src/beambot/beambot/agent/` | LLM agent that calls MCP tools. It reads a `.mcp.json` found from the current directory (not in this repo) to decide which MCP servers to start over stdio. Prompt in `robot_operation.md`. |
| Beambot GUI | Process | `src/beambot_gui/` | PyQt task script editor and chat panel. A ROS client: its node `beambot_gui_client` sends `beambot_execution` goals (through an action client) and subscribes to topics. |
| bluesky_ros | Python module | `src/bluesky_ros/` | Ophyd device so a Bluesky plan can send a task script to the `/beambot_execution` ROS action. The device class in `beambot_ophyd_device.py` is itself a ROS node (default name `mtc_executor`, set by its `name` argument) and uses an action client, so it is a ROS client. <FILL IN: the `src/bluesky_ros/README.md` example imports `beambot_ophyd_device_async` and `BeambotExecutionDeviceAsync`, which are not in this repo> |
| Discovery server | Fast DDS process | Lab, or the local-test container | Lets ROS 2 nodes on different machines find each other when ROS multicast discovery is unavailable. Can be the local-test `erobs-discovery-server.service` or one hosted elsewhere in the lab: say which. Addresses are site-specific and are not recorded in this repo. |
| EPICS IOC | Process | Not in this repo | Planned: an EPICS IOC on a VM on the lab EPICS network, talking to a ROS 2 node on the control VM. <FILL IN: repo, VM role and interface, once decided> |
| Quadlet | Podman systemd generator | Not yet used | Declares a container as a `.container` file instead of a hand-written `podman run` in a systemd service file. |
