# Extensible Robotic Beamline Scientist

Project repository for building extensible robotic beamline scientists at NSLS-II.

## Documentation

- [docs/glossary.md](./docs/glossary.md): what each name in this project means, and which words to avoid on their own.
- [docs/architecture.md](./docs/architecture.md): the moving parts, how a command flows, ports and deployment.

## Source Contents

ROS 2 packages and related directories under [src](./src). The ROS software is called beambot.

- [beambot](./src/beambot): ROS package with the orchestrator, the task-step action servers, the MCP server, the robot agent, launch files and beamline configs.
- [beambot_interfaces](./src/beambot_interfaces): ROS action definitions (`BeambotExecution` and the task-step actions).
- [beambot_gui](./src/beambot_gui): PyQt task script editor and chat panel.
- [bluesky_ros](./src/bluesky_ros): Python module for sending task scripts from Bluesky (an Ophyd device).
- [end_effectors](./src/end_effectors): End effector drivers and configuration (grippers, vacuum). Drivers not kept here are listed in `end_effectors.repos`.
- [vision](./src/vision): Camera driver list (`vision.repos`).
- [custom-ur-descriptions](./src/custom-ur-descriptions): Per-beamline robot descriptions and MoveIt configs (`cms_*`, `lix_*`).
- [cms](./src/cms), [lix](./src/lix): Empty in git (`.gitkeep` only). `example_cms_beamline.yaml` expects the CMS poses file at `src/cms/poses.yaml`, and the GUI saves runs under `src/cms/runs/`.

## Container Contents

We use Podman. [docker/jazzy_runtime](./docker/jazzy_runtime) holds the runtime image (ROS 2 Jazzy with the workspace built) and the systemd service that runs it. See [docs/architecture.md](./docs/architecture.md#systemd-services-and-podman-containers).

## Notes on VSCode Workspace

VSCode ROS2 Workspace Template Borrowed from @althack.

This template will get you set up using ROS2 with VSCode as your IDE. And help ensure consistent development across the project.

See [how she develops with vscode and ros2](https://www.allisonthackston.com/articles/vscode_docker_ros2.html) for a more in-depth look on how to use this workspace.

ROS2-approved formatters are included in the IDE.

- **c++** uncrustify; config from `ament_uncrustify`
- **python** autopep8; vscode settings consistent with the [style guide](https://index.ros.org/doc/ros2/Contributing/Code-Style-Language-Versions/)
