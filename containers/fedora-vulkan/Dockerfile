# https://medium.com/@andreask_75652/m-series-macs-gpu-accelerated-containers-f09d5e54a1b2
# *** M-series Mac GPU-access from containers via Vukan (krunkit) base image ***
# currently requires Fedora 40 due to patched mesa-driver for GPU-remoting
ARG FEDORA_VERSION=40
FROM fedora:$FEDORA_VERSION
USER 0

# install patched mesa driver for GPU remoting and some tools
RUN dnf -y install dnf-plugins-core \
 && dnf -y install dnf-plugin-versionlock \
 && dnf -y install mesa-vulkan-drivers vulkan-loader-devel vulkan-headers vulkan-tools\
 && dnf -y copr enable slp/mesa-krunkit fedora-40-aarch64 \
 && dnf -y downgrade mesa-vulkan-drivers.aarch64 — repo=copr:copr.fedorainfracloud.org:slp:mesa-krunkit \
 && dnf versionlock mesa-vulkan-drivers \
 && dnf update -y \
 && dnf clean all \
 && rm -rf /var/cache/dnf

# Set working directory
WORKDIR /app

# Default command
CMD [“/bin/bash”]