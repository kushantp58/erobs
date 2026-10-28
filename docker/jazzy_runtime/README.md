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
- The service runs ROS on domain 65, set in `erobs-jazzy-runtime.service`. The image
  itself uses the ROS default (domain 0); pass `-e ROS_DOMAIN_ID=65` to match the
  service when running it by hand.

## Rosbridge

Rosbridge (port 9090) binds to `localhost` by default and has no authentication.
Remote MCP clients cannot connect unless you change this:

- Bind to all interfaces, only on a trusted network:
  `rosbridge_address:=0.0.0.0` (for the service, add it to `LAUNCH_ARGS` with
  `systemctl edit erobs-jazzy-runtime.service`).
- Or keep the default and use an SSH tunnel from the client:
  `ssh -L 9090:localhost:9090 <host>`
