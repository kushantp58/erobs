# Architecture

Terms are defined in [glossary.md](glossary.md). This describes what the code in this
repo currently does, from the code and from upstream source and documentation. Nothing
here has been tested on the VM or the robot unless a statement says so. Planned parts are
marked.

Contents:

- [Overview](#overview)
- [Layers](#layers)
- [How a command flows](#how-a-command-flows)
- [Task script and ROS action fields](#task-script-and-ros-action-fields)
- [ROS nodes, ROS actions, topics](#ros-nodes-ros-actions-topics)
- [systemd services and Podman containers](#systemd-services-and-podman-containers)
- [Configuration](#configuration)
- [Communication paths](#communication-paths)
  - [Path notes](#path-notes)
  - [Required and optional paths](#required-and-optional-paths)
  - [UR driver connection sequence](#ur-driver-connection-sequence)
  - [EPICS interface options (undecided)](#epics-interface-options-undecided)
- [Networking](#networking)
- [Deployment](#deployment)

## Overview

```text
 Clients (any machine)                    control VM                        Beamline
 ---------------------      ---------------------------------------      -----------
 Beambot GUI        (ROS)--+
 Bluesky / bluesky_ros(ROS)+--DDS-->  runtime container
 MCP server + agent (ROS)--+          (erobs-jazzy-runtime.service)
                                      +---------------------------+
 rosbridge client -WebSocket--------> | rosbridge gateway         |
                                      | orchestrator -> ROS action|--> UR controller
                                      |   action servers          |--> end effector
                                      | MoveIt, UR driver (*)     |--> Zivid camera
                                      +---------------------------+

 Planned: EPICS IOC (lab EPICS network VM) <---> ROS 2 node on the control VM
```

(*) Not started with the container. The orchestrator starts MoveIt and the UR driver when
it receives a goal (see "ROS nodes, ROS actions, topics").

Everything on the control VM runs in one container with host networking, started by one
systemd service. Clients are separate processes and may run anywhere they can reach the VM.

## Layers

1. Hardware: UR5e arm and its UR controller, end effectors (HandE, ePick and 2FG7 grippers, and the pipettor),
   Zivid camera. The arm is reached over the network at `robot.ip` from the beamline
   config.
2. Runtime container (`docker/jazzy_runtime/`): ROS 2 Jazzy with the workspace built.
   The entrypoint `utils/start_mcp_robot_stack.sh` sources the workspace, checks that
   `BEAMBOT_BEAMLINE_CONFIG` is set, and runs `beambot_bringup.launch.py`. Output is also
   copied to `/tmp/beambot_launch.log` inside the container.
3. Launch (`src/beambot/launch/beambot_bringup.launch.py`): starts the nodes listed under
   "ROS nodes, ROS actions, topics". MoveIt and the UR driver are not started here: the
   orchestrator starts them later, when it receives a goal.
   Switches: `use_mock_hardware`, `enable_vision`, `enable_pipettor`, `enable_joystick`,
   `enable_batching`, `enable_rosbridge`.
4. Orchestrator and action servers (`src/beambot/beambot/action_servers/`): see below.
5. Clients: ROS clients (anything that speaks ROS 2 actions, ROS services or topics) and rosbridge
   clients (anything that speaks WebSocket to the rosbridge gateway).

## How a command flows

1. A ROS client (the Beambot GUI, the MCP server or the Bluesky device) sends a goal to
   the `beambot_execution` ROS action
   (`BeambotExecution.action`). The goal is `full_json`, a task script, plus an optional
   `dry_run`.
2. The orchestrator parses the task script (`utils/task_parser.py`), starts MoveIt and the
   UR driver if they are not already running for the `start_gripper` (see "ROS nodes,
   ROS actions, topics"), builds a MoveIt Task Constructor (MTC) task (`motion/`), and
   executes it. With `enable_batching` it merges
   consecutive `moveto` and `end_effector` task steps into one MTC task. Without it, each
   task step goes through its own ROS action.
3. Feedback reports `current_step`, `current_action` (the task step being run), `progress_percentage` and
   `current_gripper` (the attached end effector). The result reports `success`, `error_message`, step counts and the
   last detected pose (position and orientation of the detected object in `base_link`).
4. Cancelling stops after the active task step or batch. It is not an emergency stop.

All motion should go through `beambot_execution`. The task-step action servers skip end effector
tracking, MoveIt lifecycle handling and the vacuum watchdog.

## Task script and ROS action fields

This section may move to a separate `task_interface.md` later.

A task script is a JSON object sent as a string in the `full_json` field. It is not a
nested object. Example, using placeholder saved pose names:

```json
{
  "start_gripper": "hande",
  "tasks": [
    {"task_type": "moveto", "target": "home"},
    {"task_type": "moveto", "target": "", "direction": "down", "distance": 0.05},
    {"task_type": "end_effector", "end_effector_action": "hande_closed"}
  ],
  "poses": {"home": [0, -90, 90, -90, -90, 0]}
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `start_gripper` | yes | The end effector attached at the start. Must be a key under `grippers` in the beamline config (the config key is `grippers`, and it includes `none` and the pipettor). |
| `tasks` | yes | Non-empty list of task steps, run in order. |
| `poses` | no | Saved pose name -> six joint angles in degrees. Names not given here are looked up in the poses file from the beamline config. |

Each task step has a `task_type`:

| `task_type` | What it does |
| --- | --- |
| `moveto` | Moves to a saved pose or MoveIt state (`target`), or by `direction` and `distance`, or to `cartesian_target` (3 numbers, or 6 with roll, pitch, yaw in degrees). Give exactly one of the three. |
| `end_effector` | Actuates the attached end effector. `end_effector_action` is a MoveIt state name from the config (e.g. `hande_closed`, `vacuum_on`), not "open" or "close". |
| `tool_exchange` | Swaps the end effector (`operation`, `gripper`). |
| `vision_scan` | Scans with the camera. Needs `enable_vision`. |
| `vision_task` | General vision step. The names below are presets of it. Needs `enable_vision`. |
| `vision_moveto`, `pick_sample`, `place_sample`, `pick_spincoater`, `place_spincoater` | Vision task presets. Explicit fields in the step override the preset. |
| `pipettor` | Pipettor `operation` (e.g. `SUCK`, `EXPEL`, `EJECT_TIP`). Needs `enable_pipettor`. |
| `pause` | Pauses the script until the `beambot/resume` ROS service is called or the goal is cancelled. |
| `pickup_tip`, `pickup_vial` | Macros, not task steps the servers see: the parser expands each into task steps from the `tip_rack` and `vial_rack` entries under `vision_targets` in the beamline config. |

The parser rejects a script with an unknown `task_type`, an unknown gripper, or an invalid
`moveto`, before anything moves. `dry_run` only accepts `moveto` and `end_effector`.

The `beambot_execution` ROS action (`BeambotExecution.action`):

| Part | Field | Meaning |
| --- | --- | --- |
| Goal | `full_json` | The task script string. |
| Goal | `dry_run` | Plan only, no motion. |
| Feedback | `current_step`, `current_action` | Which task step is running (`current_action` is the `task_type`). |
| Feedback | `progress_percentage`, `status_message` | Progress and text. |
| Feedback | `current_gripper` | The attached end effector. |
| Result | `success`, `error_message` | Outcome. |
| Result | `completed_steps`, `total_steps` | Counts of task steps. |
| Result | `detected_position`, `detected_orientation` | Last detect-only pose in `base_link`: XYZ in metres and a quaternion `[x, y, z, w]`. Empty if none. |

The robot agent's own reference for writing task scripts is
`src/beambot/beambot/agent/robot_operation.md`. It is the detailed source for each
task step's fields.

## ROS nodes, ROS actions, topics

Names taken from the launch files and node constructors. Namespaces are not used.
Confirm with `ros2 node list` on the VM.

Started with the runtime container, by `beambot_bringup.launch.py` (the `beambot`
package). The runtime service file passes `enable_vision:=false enable_pipettor:=false`
by default, so rows with those conditions are off unless that is overridden:

| Node name | Executable | Condition | Serves |
| --- | --- | --- | --- |
| `beambot_orchestrator` | `orchestrator.py` | always | ROS action `beambot_execution`; ROS services `beambot/pause`, `beambot/resume`; topics `beambot/execution_state`, `beambot/current_gripper` |
| `beambot_moveto_server` | `move_to_server.py` | always | ROS action `beambot_moveto` |
| `beambot_endeffector_server` | `end_effector_server.py` | always | ROS action `beambot_endeffector` (actuates the attached end effector) |
| `beambot_toolexchange_server` | `tool_exchange_server.py` | always | ROS action `beambot_toolexchange` |
| `beambot_vision_server` | `vision_scan_server.py` | `enable_vision` | ROS action `beambot_vision_scan` |
| `beambot_vision_task_server` | `vision_task_server.py` | `enable_vision` | ROS action `beambot_vision_task` |
| `beambot_sample_server` | `sample_pick_place_server.py` | `enable_vision` | ROS actions `beambot_pick_sample`, `beambot_place_sample` |
| `zivid_camera` | `zivid_camera` (package `zivid_camera`) | `enable_vision` | camera topics and a ROS capture service |
| `beambot_pipettor_server` | `pipettor_server.py` | `enable_pipettor` | ROS action `beambot_pipettor` |
| rosbridge gateway nodes | `rosbridge_websocket_launch.xml` (package `rosbridge_server`) | `enable_rosbridge` | WebSocket on port 9090. Starts two nodes from the upstream launch file: `rosbridge_websocket` (the gateway) and `rosapi` (topic, ROS service and parameter lookup). Defaults: listens on all interfaces, no TLS, no topic filters. |

`beambot_sample_server` serves a second ROS action, `beambot_place_sample`.

Started later, by the orchestrator when it receives a goal, not by the bringup launch file
(`utils/moveit_lifecycle_manager.py` runs `ros2 launch <moveit_package>
robot_bringup.launch.py` as a child process, with `moveit_package` from the beamline
config and the attached end effector chosen at runtime):

| Node name | Source |
| --- | --- |
| `move_group` | MoveIt, default name |
| `rviz2` | MoveIt, default name. Started by the MoveIt launch file with no launch argument to turn it off. Needs a display: check whether it is wanted on the VM. |
| UR driver nodes | `ur_robot_driver` `ur_control.launch.py`, upstream names (e.g. `ur_robot_state_helper`, `ur_tool_comm`, `controller_stopper`, `controller_manager`) |
| ros2_control controller spawners | `controller_manager spawner`: `joint_state_broadcaster` and the end effector ros2_control controllers (`epick_*`, `gripper_action_controller`) |
| `onrobot_2fg7_driver` | 2FG7 only |
| `pipette_driver_node` | pipettor only |
| `game_controller_node`, `translation_teleop`, `rotation_teleop`, `servo_node` | `enable_joystick` only (joystick teleop: a gamepad jogs the arm through MoveIt Servo) |

The orchestrator starts MoveIt and the UR driver when it receives a goal, before it runs
any task step. They are not started by the systemd service or the bringup launch file, so
a fresh VM will not show them in `ros2 node list` until the first task script is sent. The
arm connection is also first opened then: a wrong robot address or a blocked port shows
up as "Failed to initialize MoveIt stack" on the first goal, not when the systemd service
starts. Once started they keep running between goals. MoveIt restarts when a goal has a
different `start_gripper` or a `tool_exchange` step changes the end effector, and stops
when the orchestrator shuts down.

Open decision: whether the UR driver should run continuously or stay on demand. This
document describes the current on-demand behavior.

Separate launch file, not used by the bringup (`octomap_mapping.launch.py`):
`pointcloud_relay`, `octomap_server` (an upstream node name), `octomap_to_planning_scene`.

ROS client nodes:

| Node name | Where | Notes |
| --- | --- | --- |
| `beambot_mcp_bridge` | MCP server | The MCP server's ROS node (the name says bridge, but it is not a network bridge). Subscribes to `/joint_states`, `/beambot/current_gripper`, `/beambot/execution_state`, `/object_detection_status`. Sends `/beambot_execution` goals. |
| `beambot_gui_client` | Beambot GUI | Sends `beambot_execution` goals. |
| (node name set by the Ophyd device) | `bluesky_ros` | Sends `beambot_execution` goals. |
| `beambot_mtc` | Inside the orchestrator process | C++ node for MoveIt Task Constructor (MTC). It shows up in `ros2 node list`. |

## systemd services and Podman containers

Two different names exist for the runtime: the systemd service name and the container name. They
do not currently match.

| systemd service | Podman container name | Image | Purpose |
| --- | --- | --- | --- |
| `erobs-jazzy-runtime.service` | `beambot_ros` | `<registry>/<owner>/erobs-jazzy-runtime:latest` | The ROS stack: the nodes started by the bringup launch file, plus MoveIt and the UR driver once the orchestrator starts them |
| `erobs-discovery-server.service` | `erobs_discovery_server` | `docker.io/library/ros:jazzy-ros-base` | Fast DDS discovery server, local testing only |

- Source: `docker/jazzy_runtime/`. `erobs-discovery-server.service` exists only on the
  `pr-docker` branch so far.
- The container name is the `CONTAINER_NAME` variable in each systemd service file, so
  `podman ps` shows `beambot_ros` and `systemctl status` shows
  `erobs-jazzy-runtime.service`. Both services run `podman run --network host`.
- The services are meant to run as systemd system services (managed with `sudo systemctl`,
  not `systemctl --user`). They have no `User=`, so they run as root and Podman runs
  rootful. `%h` in `REGISTRY_AUTH_FILE` is therefore root's home: make the `podman login`
  from the service file's comment as root, so the auth file is where the service looks.
  The files use `WantedBy=default.target` where system units usually use
  `multi-user.target`. Both work.
- The runtime image defaults to ROS domain ID 0. On `pr-docker` the runtime service
  overrides it to 65, so a ROS client on the default ID will not see the stack.
- `systemctl status` showing `erobs-jazzy-runtime.service` as active says the container is
  running. It does not show whether MoveIt or the UR driver is running, or whether the arm
  is reachable: those start at the first goal.
- Not yet existing: systemd services for the MCP server, the GUI, and an EPICS IOC.

Check on the VM:

```bash
systemctl status erobs-jazzy-runtime.service
podman ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
```

## Configuration

- One YAML per beamline, chosen by `BEAMBOT_BEAMLINE_CONFIG`. No default, so the wrong
  beamline cannot load silently. Template: `src/beambot/config/example_cms_beamline.yaml`.
- It holds the robot address, arm joints, scaling factors, per-end-effector settings (the config key is `grippers`), the
  poses file (saved poses) and the scene file.
- Site values (robot address, registry, discovery server address) are supplied at deploy time
  and are not committed. See the Deployment section.

## Communication paths

Direction is "initiator -> listener". UR driver ports are from the UR driver sequence
diagram (see "UR driver connection sequence" below). Ports described as a UR default are
not set in this repo.

Status cells say where a fact comes from: Repo (this repo's code or config), Upstream
(source or documentation of the UR driver, UR client library, rosbridge, Zivid or Podman,
not run here) or Unverified (still to check on the CMS network or the VM).
`<FILL IN: ...>` marks something a person needs to supply. It must not contain real
addresses or hostnames: describe the role instead.

| # | From -> To | Protocol / port | Needed for |
| --- | --- | --- | --- |
| 1 | control VM -> UR controller | Primary interface 30001 (version and kinematics info), RTDE 30004 (setup, start, then 500 Hz data stream), secondary interface 30002, dashboard 29999 | Driving the arm, reading state |
| 2 | UR controller -> control VM | Script sender 50002, reverse interface 50001, trajectory point interface 50003, script command interface 50004 (see the sequence below) | External Control program on the UR controller connects back to the driver |
| 3 | control VM -> UR controller tool port | TCP 54321, bridged to the serial device `/tmp/ttyUR` by `socat` | End effector serial/Modbus (HandE, ePick, 2FG7) and the pipettor (path 4) |
| 4 | control VM -> pipettor | Same as path 3: `pipette_driver_node` reads `/tmp/ttyUR` | Pipettor |
| 5 | control VM -> Zivid camera | Zivid SDK over Ethernet | 3D capture |
| 6 | ROS client -> control VM, native ROS 2 | Fast DDS: UDP, ROS domain ID from `ROS_DOMAIN_ID` | Beambot GUI, Bluesky device, MCP server, `ros2` command |
| 7 | ROS client <-> Fast DDS discovery server | UDP, port set by `--udp-port` in the discovery server service file | ROS discovery in discovery server mode, for when multicast is blocked |
| 8 | rosbridge client -> control VM, rosbridge gateway | WebSocket, TCP 9090 | Clients that do not run ROS |
| 9 | Container image: registry -> control VM | HTTPS to the image registry | Pulling `erobs-jazzy-runtime` |
| 10 | MCP server -> LLM gateway | HTTPS, endpoint set by `HERMES_ENDPOINT`, key in `AIFAPIM_API_KEY` | Robot agent |
| 11 | Ansible control host -> control VM | SSH | Deployment |
| 12 | EPICS IOC <-> ROS 2 node on control VM | Channel Access / pvAccess (TCP and UDP 5064/5065, 5075/5076 are the EPICS defaults) plus whatever the ROS side uses | EPICS integration |

### Path notes

- Path 1. All four ports are used with real hardware. With `use_mock_hardware`, 30002 is
  skipped and the dashboard client is not started.
  - Repo: the orchestrator sends `set_tool_voltage` to 30002 on the first MoveIt launch,
    for every end effector, even those that want 0 V.
  - Upstream: 30004, and 29999 for the UR driver's dashboard client, which makes the Play
    call that starts the External Control program (29999 is the UR default, not set in
    this repo). 30001 is from the UR sequence diagram.
  - Unverified: <FILL IN: does the lab firewall allow 30001, 30002, 30004 and 29999 from the control VM to the UR controller? Yes/no, and who checked>
- Path 2. Needs an inbound allow on the VM for 50001-50004.
  - Upstream: the driver listens on these ports on all interfaces, and the UR controller
    fetches the script from the host IP set in the External Control program on the teach
    pendant (see the `reverse_ip` note below).
  - Unverified: that the driver's address and the teach pendant address are both the VM's
    address as the UR controller sees it on the CMS network.
- Path 3. With real hardware.
  - Repo, from the example beamline config: HandE sets `use_tool_communication: false` and
    its own driver starts `socat` (`create_socat_tty`). ePick, 2FG7, the pipettor and `none`
    set it to true, so the UR driver does the bridging. With `use_mock_hardware` it is
    forced off.
  - Upstream: 54321 is the UR driver's default tool port.
  - Unverified: the beamline config used on the CMS network (this describes the example
    config).
- Path 4. Not a separate network path: the pipettor sits on the arm's tool port. Only with
  `enable_pipettor` and the `pipettor` end effector.
- Path 5. The Zivid SDK finds the camera itself (Zivid documents mDNS discovery or a
  configured address).
  - Repo: off unless `enable_vision` (the runtime service file sets it to false). The
    launch file gives `zivid_camera` no camera address or serial number.
  - Upstream: without a serial number the node uses the first camera the SDK finds. Zivid
    asks for at least 1 GbE and recommends 10 GbE.
  - Unverified: <FILL IN: how the camera is addressed here (static, DHCP or link-local) and which subnet it is on, without writing the real address in this file. Is the camera on the same subnet as the control VM, so mDNS works? Firewall rules, if any>
- Path 6. <FILL IN: decision. Do ROS clients find the stack by multicast or through a discovery server?> Verify with `ros2 topic list` from a second machine.
- Path 7. The service file exists on `pr-docker`. <FILL IN: which host runs the discovery server (role, not a hostname), and which clients use it>
- Path 8.
  - Repo: on by default (`enable_rosbridge`).
  - Upstream: no authentication, no TLS, all interfaces, no topic, service or action
    filters (see the rosbridge row under ROS nodes). Restrict access before exposing it
    beyond the trusted control network (see Networking).
  - <FILL IN: decision. Who may reach port 9090, and how is that enforced (firewall rule, bind address, or nothing yet)?>
- Path 9. Needs a registry login on the VM and outbound HTTPS (see the `podman login` note
  in the systemd service file). A deployment dependency, not a runtime one: it is needed
  to get or update the image, not for motion once the image is in local storage.
  - Repo: the service runs `podman run --pull=newer` and, per its comment, falls back to
    the local copy if the registry is unreachable.
  - Upstream: Podman suppresses pull errors when a local image exists, so with no local
    image and no registry access the container cannot start.
  - Unverified: on the VM.
- Path 10. Optional. The key stays out of the repo.
- Path 11. <FILL IN: Ansible role or playbook location once written. Nothing exists on any branch yet>
- Path 12. <FILL IN: decision by the IOC owner. See "EPICS interface options" below>

The VM name resolution, NTP and the DNS names of the registry and discovery server are
site-specific and belong in inventory, not here.

### Required and optional paths

Runtime paths, needed while the robot is operating with the image already on the VM:

- Always required for the robot to move: 1 and 2.
- Required only with the matching hardware or option: 3 (end effectors on the tool port),
  4 (pipettor), 5 (Zivid camera, `enable_vision`).
- At least one of 6 or 8 is required for any ROS client or rosbridge client on another machine. 7 is required
  only if ROS multicast discovery does not work between the ROS client and the VM.
- Optional: 10 (LLM agent), 12 (EPICS).

Deployment paths, needed to install or update the software and not for motion:

- 9: the first pull of the image, and each update. The service also checks the registry at
  every start (see path 9).
- 11: Ansible over SSH (planned).

### UR driver connection sequence

Who connects to whom matters for the firewall: the VM opens 30001 and 30004 to the
UR controller, but the UR controller opens 50001-50004 back to the VM.

This sequence is upstream behavior (UR driver and UR client library). This repo adds only
the Play call and the tool voltage call.

1. VM -> UR controller, primary interface 30001: TCP connect. The UR controller replies with a
   version message and kinematics info.
2. VM -> UR controller, RTDE 30004: `RTDE_CONTROL_PACKAGE_SETUP_OUTPUTS`, then
   `RTDE_CONTROL_PACKAGE_START`.
3. Play is pressed on the UR controller for the External Control program. The orchestrator
   does this itself: after each MoveIt launch it calls the `/dashboard_client/play` ROS
   service and waits up to 5 s for `robot_program_running` to turn true. A person can also
   press Play on the teach pendant.
4. UR controller -> VM, script sender 50002: `request_program`. The driver replies with
   `external_control.urscript`, with its own address filled in (see the `reverse_ip`
   note below).
5. The UR controller runs the script. It opens the reverse interface 50001 to the VM
   (at the address in the script), and also the trajectory point interface 50003 and
   script command interface 50004.
6. Loop at 500 Hz (every 2 ms): the UR controller streams `RTDE_DATA_PACKAGE` over 30004;
   the driver sends joint positions (`MODE_SERVOJ`) over 50001.

Setpoints are interpolated from trajectories that any ROS client (MoveIt, rqt, or your own
node) sends to the ros2_control controller `scaled_joint_trajectory_controller`.

Consequences:

- If the External Control program is not running, steps 1 and 2 succeed (state is readable)
  but the arm will not move.
- A new robot needs a one-time setup on its teach pendant, which Ansible cannot do. The
  steps match UR's installation guide for PolyScope 5 and have not been checked on the
  lab robot:
  1. Install the External Control plugin (`externalcontrol-*.urcap`, shipped in the
     `ur_robot_driver` package's `resources/` folder) on the UR controller.
  2. Create a robot program containing the External Control node. Set its host IP to the
     control VM's address as the UR controller sees it, and leave the custom port at its default.
  3. Save that program and leave it loaded. The orchestrator only sends Play. It never
     loads a program.
- Open for the lab robot: <FILL IN: the PolyScope version, and any differences in the menus. PolyScope X uses a different plugin file (URCapX), so step 1 would change>
- Open for the lab robot: <FILL IN: does the robot need to be in remote control mode for the dashboard Play call to work? Yes/no/untested>
- `reverse_ip` and the addresses involved. This repo does not set `reverse_ip`, so the UR
  driver's launch default `0.0.0.0` applies. `0.0.0.0` is a bind-all address, not one the
  UR controller could connect to, and the driver does not use it as one: `ur_robot_driver`
  turns it into an empty value. With an empty value the UR client library uses the local
  address of its own connection to the UR controller's RTDE port and writes that address
  into the URScript, and the UR controller connects back to it on 50001, 50003 and 50004.
  The listening ports bind to all interfaces either way. The host IP in the External
  Control program on the teach pendant is a separate setting: it is where the UR
  controller fetches the script, on port 50002. Both must be VM addresses the UR
  controller can reach. Read from `ur_robot_driver` 3.9.0 and `ur_client_library` 2.15.2
  source, the versions in a local test build of this Dockerfile. Unverified: the versions
  in the published runtime image, and whether the automatically chosen address is right on
  the CMS network (for example with more than one interface on the VM). Setting
  `reverse_ip` explicitly is the upstream way to override it.
- The 500 Hz loop is latency-sensitive. UR gives no maximum latency figure. Its driver
  documentation says to use a low-latency or PREEMPT_RT kernel on the machine running the
  driver, and a direct network connection to the UR controller without a switch. A VM on a
  shared network is further from that advice.
- Open for the lab robot: <FILL IN: how the control VM is connected to the UR controller (direct link or switched network), and any measured round-trip time>

### EPICS interface options (undecided)

1. A ROS 2 node on the control VM that exposes PVs itself, using pvAccess (the EPICS network protocol).
   The IOC is then not needed for the robot.
2. The IOC on the EPICS network VM calls the rosbridge gateway (path 8) over WebSocket. This needs
   TCP 9090 open from the IOC VM to the control VM (see the rosbridge note under
   Networking).
3. The IOC speaks native ROS 2 (path 6). This needs the IOC VM on the same ROS domain ID,
   and the discovery server (path 7) if ROS multicast discovery does not cross networks.

<FILL IN: is traffic routed between the EPICS network and the control VM, and which firewall rules exist?>
EPICS Channel Access relies on UDP broadcast by default, so a routed network needs
`EPICS_CA_ADDR_LIST`. This is EPICS name search, separate from ROS discovery.

<FILL IN: which option the IOC owner picks.> Each option changes which of paths 6, 7, 8 and 12 are
required.

## Networking

This section covers runtime networking. Deployment dependencies (the image registry, and
SSH for Ansible once it exists) are paths 9 and 11 and the Deployment section.

- ROS 2 uses Fast DDS. Machines that cannot use ROS multicast discovery need a Fast DDS
  discovery server. Each ROS client and the runtime container point at it with
  `ROS_DISCOVERY_SERVER` (commented example in the runtime service file). The server
  itself can be the local-test container above or one hosted elsewhere in the lab.
  ROS clients must use the same ROS domain ID (`ROS_DOMAIN_ID`) as the runtime container.
- The rosbridge gateway listens on port 9090 when `enable_rosbridge` is true (the default).
  It has no authentication in this configuration, no TLS and no topic, service or action
  filters, so anything that can reach the port can publish topics, call ROS services and
  send action goals, including `beambot_execution`. Restrict network access to the port
  before exposing it beyond the trusted control network. This repo configures no
  restriction, and none is assumed to be in place. Which restriction to use is
  undecided.
- The MCP server is not a rosbridge gateway client. It runs as its own ROS 2 node and talks to
  its MCP client (the robot agent) over stdio.

## Deployment

Current:

- `docker/jazzy_runtime/Dockerfile` builds the image. The image is published to a
  registry and pulled by the systemd service. The service uses the `latest` tag with
  `--pull=newer`, so any service start, including an automatic restart
  (`Restart=always`), can pick up a newer image when the registry is reachable. That can
  change the deployed software, including the UR driver and ROS package versions, without
  anyone updating the VM. Pinning the image (version tag or digest) is
  undecided.
- `docker/jazzy_runtime/erobs-jazzy-runtime.service` runs it with Podman. Local
  overrides go in `systemctl edit` (image, config path, launch arguments,
  `ROS_DISCOVERY_SERVER`).

Planned (not in the repo yet):

- Ansible role that installs Podman, the systemd service or quadlet, and the per-site overrides.
- A systemd service for the Fast DDS discovery server.
- systemd services for any other long-running process (MCP server, GUI) that runs on the VM.
- EPICS IOC on a lab EPICS network VM, with a ROS 2 node on the control VM as the other
  half. The interface is undecided.
