# Use AlmaLinux 9 (EL9)
FROM almalinux:9
USER 0

# 1. Setup Repositories
# Enable CRB (CodeReady Builder) and EPEL
RUN dnf -y install 'dnf-command(config-manager)' epel-release && \
    dnf config-manager --set-enabled crb && \
    dnf clean all

# 2. Install Core Build Tools & Dependencies
# We explicitly install X11/DRM libs that are missing in the minimal image
# but required by the mesa-krunkit drivers.
RUN dnf -y install \
    dnf-plugins-core \
    dnf-plugin-versionlock \
    gcc \
    gcc-c++ \
    make \
    cmake \
    git \
    vim-enhanced \
    ccache \
    ninja-build \
    python3-devel \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    python3-numpy \
    vulkan-loader \
    vulkan-loader-devel \
    vulkan-tools \
    vulkan-headers \
    libX11 \
    libX11-xcb \
    libdrm \
    libxshmfence \
    expat \
    libxml2 && \
    dnf clean all

# 3. Lock LLVM to Version 19
RUN dnf -y install llvm-libs-19.* && \
    dnf versionlock add llvm-libs && \
    dnf clean all

# 4. Install Mesa-Krunkit Drivers
RUN dnf -y copr enable slp/mesa-krunkit epel-9-aarch64 && \
    dnf -y install \
        mesa-vulkan-drivers \
        mesa-filesystem \
        --allowerasing \
        --repo=copr:copr.fedorainfracloud.org:slp:mesa-krunkit && \
    dnf versionlock add mesa-vulkan-drivers mesa-filesystem && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# 5. Build Shaderc (glslc) from Source
# EL9 lacks 'shaderc' package, so we build it manually.
RUN git clone https://github.com/google/shaderc.git /root/shaderc && \
    cd /root/shaderc && \
    # Use a recent stable release
    git checkout v2024.3 && \
    ./utils/git-sync-deps && \
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DSHADERC_SKIP_TESTS=ON \
        -GNinja && \
    cmake --build build --target install && \
    cd / && \
    rm -rf /root/shaderc

# 6. Clone & Build llama.cpp with Vulkan
RUN git clone https://github.com/ggerganov/llama.cpp.git /root/llama.cpp && \
    cd /root/llama.cpp && \
    git checkout 56d03d92be57f5880b9ed94542d87bb6effae31f && \
    # It will find glslc in /usr/local/bin
    cmake -B build -DLLAMA_VULKAN=1 && \
    cd build && \
    make install && \
    rm -rf /root/llama.cpp

# 7. Install PyTorch with Vulkan support
# Install python build dependencies first
RUN git clone --recursive --depth 1 --branch v2.4.0 https://github.com/pytorch/pytorch.git /root/pytorch && \
    cd /root/pytorch && \
    python3 -m pip install --upgrade pip setuptools wheel pyyaml typing-extensions sympy networkx jinja2 && \
    # USE_VULKAN_SHADERC_RUNTIME=1 links against the system libshaderc we built
    USE_VULKAN=1 USE_VULKAN_SHADERC_RUNTIME=1 USE_VULKAN_WRAPPER=0 python3 setup.py install && \
    cd / && \
    rm -rf /root/pytorch

# 8. Install transformers and other ML libraries
COPY requirements.txt .
RUN python3 -m pip install --upgrade --ignore-installed -r requirements.txt

WORKDIR /app
RUN mkdir -p /app/models
CMD ["/bin/bash"]