# Jazzy runtime container

Image and Podman systemd units for running the beambot stack on ROS 2 Jazzy.

## Build and test locally

```bash
podman build -f docker/jazzy_runtime/Dockerfile -t erobs-jazzy-runtime:test .
podman run --rm \
  -e BEAMBOT_BEAMLINE_CONFIG=/home/ros/ws/erobs/src/beambot/config/example_cms_beamline.yaml \
  erobs-jazzy-runtime:test use_mock_hardware:=true
```

Arguments after the image name are passed to `beambot_bringup.launch.py`.

## Notes

- The container runs as the non-root user `ros` (uid 1000). The workspace is at
  `/home/ros/ws/erobs`.
- ROS runs on domain 65. This is set in the Dockerfile and in
  `erobs-jazzy-runtime.service`; keep the two in sync.

## Rosbridge

Rosbridge (port 9090) binds to `localhost` by default and has no authentication.
Remote MCP clients cannot connect unless you change this:

- Bind to all interfaces, only on a trusted network:
  `rosbridge_address:=0.0.0.0` (for the service, add it to `LAUNCH_ARGS` with
  `systemctl edit erobs-jazzy-runtime.service`).
- Or keep the default and use an SSH tunnel from the client:
  `ssh -L 9090:localhost:9090 <host>`
