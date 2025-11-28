FROM quay.io/slopezpa/fedora-vgpu:latest

# basic dependencies
RUN dnf -y update && \
    dnf -y install \
    git \
    cmake \
    gcc-c++ \
    ninja-build \
    python3-devel \
    python3-pip \
    python3-numpy \
    python3-pyyaml \
    vulkan-headers \
    vulkan-loader-devel \
    libshaderc-devel \
    glslc \
    glslang-devel \
    libdrm-devel \
    which \
    findutils && \
    dnf clean all

WORKDIR /build

RUN git clone --recursive --depth 1 --branch v2.9.1 https://github.com/pytorch/pytorch.git

WORKDIR /build/pytorch

# some compilation flags
# fix C++ Header missing (uint8_t error)
ENV CXXFLAGS="-include cstdint"
ENV CMAKE_CXX_FLAGS="-include cstdint"
# GCC 15 is too strict about float16 vs uint16 pointers. we must allow it.
ENV CFLAGS="-Wno-incompatible-pointer-types -Wno-error=incompatible-pointer-types"
ENV CMAKE_C_FLAGS="-Wno-incompatible-pointer-types -Wno-error=incompatible-pointer-types"

# limit parallel jobs to prevent OOM
ENV MAX_JOBS=2

# vulkan config
ENV USE_VULKAN=1
ENV USE_VULKAN_API=1
ENV USE_VULKAN_SHADERC_RUNTIME=1
# disable others to speed up build
ENV USE_CUDA=0
ENV USE_ROCM=0
ENV USE_DISTRIBUTED=0
ENV USE_MKLDNN=0
ENV CMAKE_PREFIX_PATH="/usr"

# get pytorch
RUN pip3 install -r requirements.txt && \
    python3 setup.py install

# llama.cpp specific dependencies
RUN dnf install -y \
    libcurl-devel \
    openssl-devel \
    zlib-devel \
    pkgconf

# get llama-cpp
RUN git clone https://github.com/ggerganov/llama.cpp.git /root/llama.cpp
RUN cd /root/llama.cpp && \
    git checkout d82b7a7c1d73c0674698d9601b1bbb0200933f29 && \
    cmake -B build -DLLAMA_VULKAN=1 && \
    cmake --build build --target install && \
    rm -rf /root/llama.cpp

# cleanup
WORKDIR /app
RUN rm -rf /build

# runtime config
ENV VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/virtio_icd.aarch64.json"

CMD ["bash"]