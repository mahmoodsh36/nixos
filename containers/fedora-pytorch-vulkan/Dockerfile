FROM registry.fedoraproject.org/fedora:40 AS builder
RUN dnf install -y dnf-plugins-core gcc gcc-c++ make cmake git vim-enhanced ccache glslc glslang python3-devel python3-pip python3-setuptools python3-wheel python3-pyyaml python3-typing-extensions python3-numpy python3-sympy python3-networkx python3-jinja2
RUN dnf install -y vulkan-loader vulkan-loader-devel vulkan-tools vulkan-headers

ENV mesa_version=24.1.5-101
RUN dnf copr enable -y slp/mesa-krunkit
RUN dnf install -y mesa-dri-drivers-${mesa_version} mesa-filesystem-${mesa_version} mesa-libOpenCL-${mesa_version} mesa-libgbm-${mesa_version} mesa-libglapi-${mesa_version} mesa-va-drivers-${mesa_version} mesa-vulkan-drivers-${mesa_version}

RUN git clone https://github.com/ggerganov/llama.cpp.git /root/llama.cpp
RUN cd /root/llama.cpp && git checkout 56d03d92be57f5880b9ed94542d87bb6effae31f && cmake -B build -DLLAMA_VULKAN=1 && cd build && make install && rm -rf /root/llama.cpp

# Install PyTorch with Vulkan support
RUN git clone --recursive --depth 1 --branch v2.4.0 https://github.com/pytorch/pytorch.git /root/pytorch && \
    cd /root/pytorch && \
    python3 -m pip install --upgrade pip setuptools wheel && \
    USE_VULKAN=1 MAX_JOBS=2 python3 setup.py install && \
    cd / && \
    rm -rf /root/pytorch

# microdnf does not support copr, so install the rpm(s) individually
FROM registry.fedoraproject.org/fedora-minimal:40
ENV mesa_version=24.1.5-101
RUN microdnf install -y vulkan-loader python3 https://download.copr.fedorainfracloud.org/results/slp/mesa-krunkit/fedora-40-aarch64/07895967-mesa/mesa-vulkan-drivers-${mesa_version}.aarch64.rpm && microdnf clean all

COPY --from=builder /usr/local/bin/main /usr/local/bin/
COPY --from=builder /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/
