# Use the full Fedora 40 image as the base
ARG FEDORA_VERSION=40
FROM fedora:${FEDORA_VERSION}
USER 0

# Install build tools, python dependencies, Vulkan, and DNF plugins in one layer
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
    glslc \
    glslang \
    python3-devel \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    python3-pyyaml \
    python3-typing-extensions \
    python3-numpy \
    python3-sympy \
    python3-networkx \
    python3-jinja2 \
    vulkan-loader \
    vulkan-loader-devel \
    vulkan-tools \
    vulkan-headers && \
    dnf clean all

# Enable COPR repo and install Mesa-Krunkit properly
RUN dnf -y copr enable slp/mesa-krunkit fedora-40-aarch64 && \
    dnf -y install mesa-vulkan-drivers && \
    # Downgrade Mesa to COPR version and lock it
    dnf -y downgrade mesa-vulkan-drivers.aarch64 --repo=copr:copr.fedorainfracloud.org:slp:mesa-krunkit && \
    dnf versionlock mesa-vulkan-drivers && \
    dnf update -y && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Clone, build, and install llama.cpp with Vulkan support
RUN git clone https://github.com/ggerganov/llama.cpp.git /root/llama.cpp && \
    cd /root/llama.cpp && \
    git checkout 56d03d92be57f5880b9ed94542d87bb6effae31f && \
    cmake -B build -DLLAMA_VULKAN=1 && \
    cd build && \
    make install && \
    rm -rf /root/llama.cpp

# Install PyTorch with Vulkan support from source
RUN git clone --recursive --depth 1 --branch v2.4.0 https://github.com/pytorch/pytorch.git /root/pytorch && \
    cd /root/pytorch && \
    python3 -m pip install --upgrade pip setuptools wheel && \
    USE_VULKAN=1 USE_VULKAN_SHADERC_RUNTIME=1 USE_VULKAN_WRAPPER=0 python3 setup.py install && \
    cd / && \
    rm -rf /root/pytorch

# Install transformers and other ML libraries
RUN python3 -m pip install --upgrade --ignore-installed \
    transformers accelerate datasets tokenizers

# Set working directory
WORKDIR /app

# Create models directory
RUN mkdir -p /app/models

# Default command
CMD ["/bin/bash"]