#!/bin/bash
set -e

# Only use sudo when not already root (e.g. inside the container build).
SUDO=""
[[ $EUID -ne 0 ]] && SUDO=sudo

$SUDO apt-get update
command -v vcs >/dev/null 2>&1 || $SUDO apt-get install -y python3-vcstool

vcs import src/end_effectors < src/end_effectors/end_effectors.repos
vcs import src/vision < src/vision/vision.repos
# zivid_description needs no SDK; skip the packages that do when it's missing.
if [[ ! -f /usr/lib/cmake/Zivid/ZividConfig.cmake ]]; then
    touch src/vision/zivid-ros/{zivid_camera,zivid_samples}/COLCON_IGNORE
else
    rm -f src/vision/zivid-ros/{zivid_camera,zivid_samples}/COLCON_IGNORE
fi
rosdep update
rosdep install --from-paths src --ignore-src -y
