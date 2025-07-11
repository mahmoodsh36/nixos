{
  pkgs,
  config,
  ...
}: {
  imports = [ ./distrobox.nix ];

  programs.mydistrobox = {
    enable = config.machine.is_desktop;

    boxes = let
      exec = "${pkgs.zsh}/bin/zsh";
      symlinks = [
        ".zshrc"
        ".config/nvim"
      ];
      packages = [
        pkgs.neovim
        pkgs.nix
        pkgs.git
      ];
    in {
      fedora = {
        inherit exec symlinks;
        packages = ''
          nodejs npm poetry gcc wl-clipboard
        '';
        img = "registry.fedoraproject.org/fedora-toolbox:rawhide";
        nixPackages =
          packages
          ++ [
            (pkgs.writeShellScriptBin "pr" "poetry run $@")
          ];
      };
      arch = {
        inherit exec symlinks;
        img = "docker.io/library/archlinux:latest";
        packages = ''
          base-devel wl-clipboard
          neovim git
          cmake pkgfile
          cuda
          uv
        '';
        nixPackages =
          packages
          ++ [
            (pkgs.writeShellScriptBin "yay" ''
              if [[ ! -f /bin/yay ]]; then
                tmpdir="$HOME/.yay-bin"
                if [[ -d "$tmpdir" ]]; then sudo rm -r "$tmpdir"; fi
                git clone https://aur.archlinux.org/yay-bin.git "$tmpdir"
                cd "$tmpdir"
                makepkg -si
                sudo rm -r "$tmpdir"
              fi
              /bin/yay $@
            '')
            (pkgs.writeShellScriptBin "install_rest" ''
              yay -S --noconfirm python312
            '')
          ];
      };
    };
  };
}