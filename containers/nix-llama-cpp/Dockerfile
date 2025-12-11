FROM quay.io/slopezpa/fedora-vgpu:latest

# install git for cloning the flake
RUN dnf install -y git && dnf clean all

# install nix package manager
RUN curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes

# setup nix environment for subsequent RUN commands
ENV PATH="/nix/var/nix/profiles/default/bin:$PATH"

# create nix config for experimental features and caches
RUN mkdir -p /etc/nix && cat > /etc/nix/nix.conf << 'EOF'
experimental-features = nix-command flakes
substituters = https://cache.nixos.org https://nix-community.cachix.org https://llama-cpp.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= llama-cpp.cachix.org-1:H75X+w83wUKTIPSO1KWy9ADUrzThyGs8P5tmAbkWhQc=
EOF

# install llama-cpp with Vulkan support from the official flake
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix.sh && \
    nix profile install github:ggml-org/llama.cpp#vulkan --impure

# also install some useful utilities via Nix
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix.sh && \
    nix profile install nixpkgs#curl nixpkgs#jq

# setup default shell environment
RUN echo 'source /nix/var/nix/profiles/default/etc/profile.d/nix.sh' >> /root/.bashrc && \
    echo 'export PATH="/nix/var/nix/profiles/default/bin:$PATH"' >> /root/.bashrc

WORKDIR /app

# runtime config for virtio-gpu vulkan
ENV VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/virtio_icd.aarch64.json"

CMD ["bash"]