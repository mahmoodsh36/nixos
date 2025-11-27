{ lib, config, pkgs, inputs, pkgs-master, pkgs-unstable, pkgs-pinned, ... }:

let
  constants = (import ../../lib/constants.nix);
  # here, config' is the system config, while "config" might be home-manager-specific
  config' = config;
  homedir = if config.machine.is_darwin
             then "/Users/${config.machine.user}"
             else "/home/${config.machine.user}";
  voldir = config.machine.voldir;
  work_dir = "${config.machine.voldir}/work";
in
{
  imports = [
  ];

  config = {
    users.users."${config.machine.user}" = {
      shell = lib.mkDefault pkgs.zsh;
      home = homedir;
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "hmbkup";
    home-manager.extraSpecialArgs = { inherit pkgs pkgs-master pkgs-unstable pkgs-pinned inputs; };
    home-manager.sharedModules = [
    ] ++ pkgs.lib.optionals config.machine.is_linux  [
      inputs.plasma-manager.homeModules.plasma-manager
    ] ++ pkgs.lib.optionals config.machine.is_darwin  [
      inputs.mac-app-util.homeManagerModules.default
    ];

    # "lib" in home-manager configs needs to not be overridden. otherwise
    # we might cause issues
    home-manager.users."${config.machine.user}" = { lib, config, ... }:
      let
        dots = if builtins.pathExists "${work_dir}/otherdots"
               then "${work_dir}/otherdots"
               else inputs.otherdots.outPath;

        nvim_dots = if builtins.pathExists "${work_dir}/nvim"
                     then "${work_dir}/nvim"
                     else inputs.nvim.outPath;

        config_names = [
          "mimeapps.list" "mpv" "vifm" "user-dirs.dirs" "zathura" "wezterm"
          "xournalpp" "imv" "hypr" "goose" "aichat"
        ];
        config_entries = lib.listToAttrs (builtins.map (cfg_name: {
          name = ".config/${cfg_name}";
          value = {
            source = config.lib.file.mkOutOfStoreSymlink "${dots}/.config/${cfg_name}";
            force = true;
          };
        }) config_names);

        scripts_dir = if builtins.pathExists "${work_dir}/scripts"
                      then "${work_dir}/scripts"
                      else inputs.scripts.outPath;
        scripts = builtins.attrNames (builtins.readDir scripts_dir);
        script_files = builtins.filter (name: builtins.match ".*\\.(py|sh|el)$" name != null) scripts;

        script_entries = lib.listToAttrs (builtins.map (fname: {
          name  = ".local/bin/${fname}";
          value = {
            source = config.lib.file.mkOutOfStoreSymlink "${scripts_dir}/${fname}";
            force = true;
            # executable = true;
          };
        }) script_files);

        # restore .emacs.d
        emacs_d_dir = if builtins.pathExists "${work_dir}/emacs.d"
                      then "${work_dir}/emacs.d"
                      else inputs.emacs-d.outPath;
        emacs_d_files = builtins.attrNames (builtins.readDir emacs_d_dir);
        emacs_d_entries = lib.listToAttrs (builtins.map (fname: {
          name = ".emacs.d/${fname}";
          value = {
            source = config.lib.file.mkOutOfStoreSymlink "${emacs_d_dir}/${fname}";
            force = true;
          };
        }) emacs_d_files);

        # Lem-config files - symlink individual files, not the whole directory
        lem_config_dir = if builtins.pathExists "${work_dir}/lem-config"
                        then "${work_dir}/lem-config"
                        else inputs.lem-config.outPath;
        lem_config_files = builtins.attrNames (builtins.readDir lem_config_dir);
        lem_config_entries = lib.listToAttrs (builtins.map (fname: {
          name = ".config/lem-config/${fname}";
          value = {
            source = config.lib.file.mkOutOfStoreSymlink "${lem_config_dir}/${fname}";
            force = true;
          };
        }) lem_config_files);
      in {
        _module.args = {
          config' = config';
        };

        /* the home.stateVersion option does not have a default and must be set */
        home.stateVersion = "24.05";

        imports = [
          ../../modules/machine-options.nix
          ../machine-config.nix
          ./home-desktop.nix
          ./vscode.nix
          ./zed.nix
          # ./plasma.nix
          ./python.nix
          # ./julia.nix
          ./sbcl.nix
          ./distrobox-config.nix
          ../../services/podman-autobuilder.nix
        ];

        home.file = config_entries // script_entries // emacs_d_entries // lem_config_entries // {
          ".zshrc.manual" = {
            source = config.lib.file.mkOutOfStoreSymlink "${dots}/.zshrc";
          };
          ".zprofile" = {
            source = config.lib.file.mkOutOfStoreSymlink "${dots}/.zprofile";
          };
          ".config/nvim" = {
            source = config.lib.file.mkOutOfStoreSymlink nvim_dots;
          };
        };

        programs.zsh = {
          enable = true;
          # https://github.com/nix-community/home-manager/issues/7633
          # we use a custom .zshrc.manual to avoid issues
          initContent = lib.mkOrder 1500 ''
            source ~/.zshrc.manual
          '';
          syntaxHighlighting.enable = true;
          # lsp causes high cpu usage for some reason (400%?)
          # enableCompletion = true;
          autosuggestion = {
            enable = true;
            strategy = [
              "match_prev_cmd"
              "completion"
            ];
          };
          sessionVariables = rec {
            # we want our rsync to precede macos' default rsync to support options like --iconv
            # PATH = "${pkgs.rsync}/bin:" + (builtins.getEnv "PATH");
            # this doesnt seem to take effect?
            # PATH = builtins.concatStringsSep ":" [
            #   "${pkgs.rsync}/bin"
            #   "${pkgs.coreutils}/bin"
            #   "${builtins.getEnv "PATH"}"
            # ];

            PYTHON_HISTORY = "$HOME/brain/python_history";
            HOME_DIR = homedir;
            VOL_DIR = voldir;
            BRAIN_DIR = "${VOL_DIR}/brain";
            MUSIC_DIR = "${VOL_DIR}/music";
            WORK_DIR = work_dir;
            work = WORK_DIR;
            mahmooz1 = constants.mahmooz1_addr;
            brain = BRAIN_DIR;
            VOLUME_DIR = voldir;
            vol = VOLUME_DIR;
            NOTES_DIR = "${BRAIN_DIR}/notes";
            SCRIPTS_DIR = "${WORK_DIR}/scripts";
            DOTFILES_DIR = "${WORK_DIR}/otherdots";
            EMACS_D_DIR = "${WORK_DIR}/emacs.d";
            LEM_CONFIG_DIR = "${WORK_DIR}/lem-config";
            NIX_CONFIG_DIR = "${WORK_DIR}/nixos";
            BLOG_DIR = "${WORK_DIR}/blog";
            EDITOR = "nvim";
            BROWSER = "firefox";
            DATA_DIR = "${VOL_DIR}/data";
            MPV_SOCKET_DIR = "${DATA_DIR}/mpv_data/sockets";
            MPV_MAIN_SOCKET_PATH = "${DATA_DIR}/mpv_data/sockets/mpv.socket";
            MYGITHUB = constants.mygithub;
            PERSONAL_WEBSITE = constants.personal_website;
            MAHMOOZ3_ADDR = constants.mahmooz3_addr;
            MAHMOOZ2_ADDR = constants.mahmooz2_addr;
            MAHMOOZ1_ADDR = constants.mahmooz1_addr;
            MYDOMAIN = constants.mydomain;
            # LLAMA_CACHE = lib.mkIf (builtins.pathExists constants.models_dir) constants.models_dir;
            CONTAINERS_MACHINE_PROVIDER = "libkrun";
          };
        };

        # ls alternative
        # programs.eza = {
        #   enable = true;
        #   git = true;
        #   icons = "auto";
        #   extraOptions = [
        #     "--group-directories-first"
        #     "--header"
        #     "--hyperlink"
        #     "--follow-symlinks"
        #   ];
        # };

        programs.home-manager.enable = true;

        # i dont think im even making use of this
        programs.neovim = {
          enable = true;
          plugins = with pkgs.vimPlugins; [
            nvim-treesitter.withAllGrammars
          ];
          viAlias = true;
          vimAlias = true;
          vimdiffAlias = true;
          withNodeJs = true;
          withPython3 = true;
        };

        home.packages = with pkgs; [
        ] ++ lib.optionals config'.machine.is_linux [
          # to avoid some errors
          pkgs.dconf
        ];

        programs.git = {
          enable = true;
          userName = "mahmoodsh36";
          userEmail = "mahmod.m2015@gmail.com";
        };

        services.podman-autobuilder = {
          enable = true;
          podmanPackage = pkgs.podman;

          containers = {
            # test-alpine = {
            #   imageName = "test-alpine:latest";
            #   context = ../../containers/test-container;
            #   dockerfile = "Dockerfile";
            #   runArgs = [
            #     "--network=host"
            #   ];
            #   command = [ "sleep" "infinity" ];
            #   aliases = {
            #     "test-shell" = {
            #       command = [ "sh" ];
            #       interactive = true;
            #     };
            #     "test-bash" = {
            #       command = [ "bash" ];
            #       interactive = true;
            #     };
            #     "test-curl" = {
            #       command = [ "curl" ];
            #       interactive = false;
            #     };
            #   };
            # };

            # ML Python environment with CUDA support (for Linux/NVIDIA)
            # mlpython = lib.mkIf (config'.machine.is_linux && config'.machine.enable_nvidia) {
            #   imageName = "mlpython";
            #   context = ../../containers/mlpython;
            #   buildArgs = [
            #     "--network=host"
            #     "--build-arg" "MAX_JOBS=8"
            #   ];
            #   runArgs = [
            #     "--cdi-spec-dir=/run/cdi"
            #     "--device=nvidia.com/gpu=all"
            #     "--shm-size=64g"
            #     "-v" "${constants.models_dir}:${constants.models_dir}"
            #     "-v" "/:/host" # full filesystem access
            #     "--network=host"
            #   ];
            #   command = [ "sleep" "infinity" ];
            #   aliases = {
            #     "mlpython" = {
            #       command = [ "python3" ];
            #       interactive = true;
            #     };
            #     "myvllm" = {
            #       command = [
            #         "python3" "-m" "vllm.entrypoints.openai.api_server"
            #         "--download-dir" "${constants.models_dir}" "--trust-remote-code"
            #         "--port" "5000" "--max-num-seqs" "1"
            #       ];
            #       interactive = true;
            #     };
            #   };
            # };

            # MinerU container (for Linux)
            # mineru = lib.mkIf config'.machine.is_linux {
            #   imageName = "mineru";
            #   context = ../../containers/mineru;
            #   buildArgs = [
            #     "--network=host"
            #   ];
            #   runArgs = [
            #     "-v" "/:/host"
            #     "--network=host"
            #   ] ++ pkgs.lib.optionals config'.machine.enable_nvidia [
            #     "--cdi-spec-dir=/run/cdi"
            #     "--device=nvidia.com/gpu=all"
            #   ];
            #   command = [ "sleep" "infinity" ];
            #   aliases = {
            #     "minerupython" = {
            #       command = [ "python3" ];
            #       interactive = true;
            #     };
            #     "mineru" = {
            #       command = [ "mineru" ];
            #       interactive = true;
            #     };
            #   };
            # };

            # CPU version (for macOS - MLX not available in containers)
            # mineru-mlx = lib.mkIf config'.machine.is_darwin {
            #   imageName = "mineru-mlx";
            #   context = ../../containers/mineru-mlx;
            #   buildArgs = [
            #     "--network=host"
            #     "--platform=linux/arm64"
            #   ];
            #   runArgs = [
            #     "-v" "/:/host"
            #     "--network=host"
            #     "--platform=linux/arm64"
            #   ];
            #   command = [ "sleep" "infinity" ];
            #   aliases = {
            #     "minerupython" = {
            #       command = [ "python3" ];
            #       interactive = true;
            #     };
            #     # "mineru" = {
            #     #   command = [ "mineru" ];
            #     #   interactive = true;
            #     # };
            #     # "mineru-mlx" = {
            #     #   command = [ "python3" ];
            #     #   interactive = true;
            #     # };
            #   };
            # };

            # fedora-vulkan = lib.mkIf config'.machine.is_darwin {
            #   imageName = "fedora-vulkan";
            #   context = ../../containers/fedora-vulkan;
            #   buildArgs = [
            #     # "--network=host"
            #   ];
            #   runArgs = [
            #     # "--network=host"
            #     "--device" "/dev/dri"
            #   ];
            #   command = [ "sleep" "infinity" ];
            #   aliases = {
            #     "myvulkaninfo" = {
            #       command = [ "vulkaninfo" ];
            #       interactive = true;
            #     };
            #     # "mineru" = {
            #     #   command = [ "mineru" ];
            #     #   interactive = true;
            #     # };
            #     # "mineru-mlx" = {
            #     #   command = [ "python3" ];
            #     #   interactive = true;
            #     # };
            #   };
            # };

            fedora-pytorch-vulkan = lib.mkIf config'.machine.is_darwin {
              imageName = "fedora-pytorch-vulkan";
              context = ../../containers/fedora-pytorch-vulkan;
              buildArgs = [
                # "--network=host"
                "--memory=32000m"
              ];
              runArgs = [
                # "--network=host"
                "--entrypoint=" # Clear the broken ENTRYPOINT from base image
                "--device" "/dev/dri"
                "--memory" "32g"
                # "-v" "${config'.machine.voldir}/models:/app/models"
                "-e" "HF_HOME=/app/models"
                "-e" "TRANSFORMERS_CACHE=/app/models"
                "-e" "HUGGINGFACE_HUB_CACHE=/app/models"
              ];
              command = [ "sleep" "infinity" ];
              aliases = {
                "pytorch-vulkan" = {
                  command = [ "python3" ];
                  interactive = true;
                };
                "pytorch-vulkaninfo" = {
                  command = [ "vulkaninfo" ];
                  interactive = true;
                };
                "vulkan-transformers" = {
                  command = [ "transformers" ];
                  interactive = false;
                };
              };
            };
          };

          composeFiles = {
            # open-notebook = {
            #   # composeFile = "${inputs.open-notebook}/docker-compose.full.yml";
            #   composeFile = "${inputs.open-notebook}/setup_guide/docker-compose.yml";
            #   workingDirectory = "${inputs.open-notebook}/setup_guide/";
            # };
            open-notebook = {
              composeFile = ../../containers/open-notebook/docker-compose.full.yml;
              workingDirectory = ../../containers/open-notebook;
              environment = {
                HOME = config.home.homeDirectory;
              };
            };
          };
        };
      };
  };
}