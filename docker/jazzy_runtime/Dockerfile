# Base image is pinned by digest. To update it (e.g. for security fixes):
#   podman pull docker.io/osrf/ros:jazzy-desktop-full
#   podman image inspect docker.io/osrf/ros:jazzy-desktop-full --format '{{.Digest}}'
# then paste the new sha256 below and re-test.
FROM docker.io/osrf/ros:jazzy-desktop-full@sha256:ae7ad3ac243da1dfd8bd402a2fa08e149ffbf7a385013bd8ef798d0800accdc8

# Install Zivid SDK 2.17.2 for Ubuntu 24.04 (Noble).
# When bumping ZIVID_VERSION, regenerate zivid.sha256 (sha256sum *.deb) from the new files.
ARG ZIVID_VERSION=2.17.2+440b2367-1
COPY docker/jazzy_runtime/zivid.sha256 /tmp/zivid.sha256
WORKDIR /tmp/zivid
# apt packages are not version-pinned: the pinned base image is the reproducibility control.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends wget && \
    wget -q https://downloads.zivid.com/sdk/releases/${ZIVID_VERSION}/u24/amd64/zivid_${ZIVID_VERSION}_amd64.deb && \
    wget -q https://downloads.zivid.com/sdk/releases/${ZIVID_VERSION}/u24/amd64/zivid-studio_${ZIVID_VERSION}_amd64.deb && \
    wget -q https://downloads.zivid.com/sdk/releases/${ZIVID_VERSION}/u24/amd64/zivid-tools_${ZIVID_VERSION}_amd64.deb && \
    wget -q https://downloads.zivid.com/sdk/releases/${ZIVID_VERSION}/u24/amd64/zivid-genicam_${ZIVID_VERSION}_amd64.deb && \
    sha256sum -c /tmp/zivid.sha256 && \
    apt-get install -y --no-install-recommends /tmp/zivid/*.deb && \
    rm -rf /tmp/zivid /tmp/zivid.sha256 /var/lib/apt/lists/*

# Run as a non-root user: rename the base image's uid 1000 user and drop its sudo access.
RUN usermod -l ros -d /home/ros -m ubuntu && groupmod -n ros ubuntu && gpasswd -d ros sudo

WORKDIR /home/ros/ws/erobs
# Own the workspace dir up front so the build below can run as ros without a recursive chown
# (a chown -R after the build would duplicate every file into a new layer).
RUN chown ros:ros /home/ros/ws /home/ros/ws/erobs

COPY --chown=ros:ros src/ src/
COPY --chown=ros:ros utils/ utils/
# Import driver repos and install ROS dependencies.
RUN chmod +x utils/setup.sh utils/start_mcp_robot_stack.sh && \
    bash utils/setup.sh && \
    rm -rf /var/lib/apt/lists/*

# Numeric uid/gid of the ros user (renamed from ubuntu above).
USER 1000:1000

RUN . "/opt/ros/${ROS_DISTRO}/setup.sh" && \
    colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release

ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp
# Non-default ROS domain; keep in sync with erobs-jazzy-runtime.service.
ENV ROS_DOMAIN_ID=65

# Source workspace in all shells (podman exec, interactive, etc.)
RUN echo "source /home/ros/ws/erobs/install/setup.bash" >> /home/ros/.bashrc

# ros2 launch only handles SIGINT; podman's default SIGTERM is ignored by PID 1 and
# every stop waits for the timeout and then SIGKILLs.
STOPSIGNAL SIGINT

ENTRYPOINT ["/home/ros/ws/erobs/utils/start_mcp_robot_stack.sh"]
