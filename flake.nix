{
  description = "nixos flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/c0b0e0fddf73fd517c3471e546c0df87a42d53f4";
    pkgs-pinned.url = "github:NixOS/nixpkgs/c0b0e0fddf73fd517c3471e546c0df87a42d53f4";
    pkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    pkgs-master.url = "github:NixOS/nixpkgs/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      # url = "github:nix-community/home-manager/a3fcc92180c7462082cd849498369591dfb20855";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lem = {
      url = "github:lem-project/lem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mpv-history-daemon = {
      url = "github:mahmoodsh36/mpv-history-daemon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    llama-cpp-flake = {
      url = "github:ggml-org/llama.cpp";
      # url = "github:ggml-org/llama.cpp/50f4281a6f5c3a5d68bdeb12f904fa01e0e2ba91";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    arion = {
      url = "github:hercules-ci/arion";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    declarative-jellyfin = {
      url = "github:Sveske-Juice/declarative-jellyfin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stable-diffusion-webui-nix = {
      url = "github:Janrupf/stable-diffusion-webui-nix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cltpt = {
      url = "github:mahmoodsh36/cltpt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs = {
      url = "github:nix-community/emacs-overlay/e434cb40e1a77ef70a4d8a848ccca91d0a7e42ad";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wezterm = {
      url = "github:wezterm/wezterm?dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-ai-tools = {
      url = "github:numtide/nix-ai-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macos
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    determinate = {
      url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    # yt-music-tap = {
    #   url = "github:th-ch/homebrew-youtube-music";
    #   flake = false;
    # };
    # for pear-desktop (yt music)
    neved4-tap = {
      url = "github:Neved4/homebrew-tap";
      flake = false;
    };
    krunkit = {
      url = "github:slp/homebrew-krunkit";
      flake = false;
    };
    # https://github.com/hraban/mac-app-util/issues/39
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.cl-nix-lite.url = "github:r4v3n6101/cl-nix-lite/url-fix";
    };
    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # android
    nix-on-droid = {
      url = "github:t184256/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    robotnix = {
      url = "github:nix-community/robotnix";
    };

    # dotfiles
    otherdots = {
      url = "github:mahmoodsh36/otherdots";
      flake = false;
    };
    nvim = {
      url = "github:mahmoodsh36/nvim";
      flake = false;
    };
    scripts = {
      url = "github:mahmoodsh36/scripts";
      flake = false;
    };
    emacs-d = {
      url = "github:mahmoodsh36/.emacs.d";
      flake = false;
    };
    lem-config = {
      url = "github:mahmoodsh36/lem-config";
      flake = false;
    };

    # for python
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs = {
    self, nixpkgs, ...
  } @inputs: let
    # define supported systems for NixOS configurations
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

    # helper to create packages for a specific system
    mkPkgs = system: import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    isobase = {
      isoImage.squashfsCompression = "gzip -Xcompression-level 1";
      isoImage.forceTextMode = true; # to avoid some issues? https://discourse.nixos.org/t/nix-iso-unable-to-boot-in-uefi-mode-but-other-distros-can/16473/53
      systemd.services.sshd.wantedBy = nixpkgs.lib.mkForce [ "multi-user.target" ];
      networking.wireless.enable = false; # installation-cd-minimal.nix sets that to true
      networking.networkmanager.enable = nixpkgs.lib.mkForce true;
      # to fix another error when generating iso
      boot.kernel.sysctl."vm.overcommit_memory" = nixpkgs.lib.mkForce "1";
      # isoImage.contents = [ { source = /home/mahmooz/work/scripts; target = "/home/mahmooz/scripts"; } ];
    };
    # Helper function to create uvpkgs for any system
    # mkUvPkgs = system: import inputs.pkgs-pinned {
    mkUvPkgs = system: import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      config.cudaSupport = true;
    };
    mkSystem = system: extraModules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs self;
          inherit system;
          myutils = import ./lib/utils.nix { inherit system; };
        };
        modules = [
          ./config.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.arion.nixosModules.arion
          inputs.declarative-jellyfin.nixosModules.default
        ]
        ++ extraModules;
      };

    forAllSystems = nixpkgs.lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    # helper to create Python environment for any system
    # usage: mkPythonEnv { system = "x86_64-linux"; workspaceRoot = ./path; envName = "my-env"; cudaSupport = true; }
    mkPythonEnv = { system, workspaceRoot, envName, cudaSupport ? false }: let
      isLinux = nixpkgs.lib.hasInfix "linux" system;
      sysPkgs = import inputs.pkgs-pinned {
        inherit system;
        config.allowUnfree = true;
        config.cudaSupport = isLinux && cudaSupport;
      };
    in import ./modules/uv_python.nix {
      pkgs = sysPkgs;
      pyproject-nix = inputs.pyproject-nix;
      uv2nix = inputs.uv2nix;
      pyproject-build-systems = inputs.pyproject-build-systems;
      python = sysPkgs.python312;
      inherit workspaceRoot envName cudaSupport;
    };
  in {
    nixosConfigurations =
      let
        mkConfigsForSystem = system: let
          machineConfigs = {
            mahmooz1 = [
              ./hardware-configuration.nix # hardware scan results
              ({ lib, ... }: {
                config = {
                  machine.name = "mahmooz1";
                  machine.is_desktop = true;
                  machine.enable_nvidia = false;
                  machine.static_ip = "192.168.1.1";
                  machine.is_home_server = true;
                };
              })
              ./profiles/network-local.nix
              inputs.disko.nixosModules.disko
              ./disko-raid1.nix
            ];
            mahmooz2 = [
              ./hardware-configuration.nix
              ({ lib, ... }: {
                config = {
                  machine.name = "mahmooz2";
                  machine.is_desktop = true;
                  machine.enable_nvidia = true;
                  machine.static_ip = "192.168.1.2";
                  machine.is_home_server = true;
                  # embed executable for mlpython
                  # environment.systemPackages = pkgs.lib.mkIf (builtins.pathExists ./uv.lock ) [
                  #   (mkUvPkgs system).writeShellScriptBin "mlpython2" ''
                  #     export LD_LIBRARY_PATH=/run/opengl-driver/lib
                  #     export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib
                  #     export TRITON_PTXAS_PATH="${(mkUvPkgs system).cudatoolkit}/bin/ptxas"
                  #     exec ${mlvenv}/bin/python "$@"
                  #   ''
                  # ];
                };
              })
              ./profiles/network-local.nix
            ];
            mahmooz3 = [
              ./hardware-configuration.nix
              {
                config = {
                  machine.name = "mahmooz3";
                  machine.is_desktop = false;
                  machine.enable_nvidia = false;
                  # needed for virtual machines
                  boot.loader.grub.efiInstallAsRemovable = true;
                  boot.loader.efi.canTouchEfiVariables = nixpkgs.lib.mkForce false;
                  boot.loader.grub.useOSProber = nixpkgs.lib.mkForce false;

                  # this might help prevent system freezing on rebuilds
                  nix.settings.max-jobs = 1;
                  nix.settings.cores = 1;
                  systemd.slices.anti-hungry.sliceConfig = {
                    CPUAccounting = true;
                    CPUQuota = "50%";
                    MemoryAccounting = true; # allow to control with systemd-cgtop
                    MemoryHigh = "50%";
                    MemoryMax = "75%";
                    MemorySwapMax = "50%";
                    MemoryZSwapMax = "50%";
                  };
                  systemd.services.nix-daemon.serviceConfig.Slice = "anti-hungry.slice";
                  # kill process using most ram after ram availability drops below
                  # a specific threshold.
                  services.earlyoom.enable = true;
                  services.earlyoom.enableNotifications = true;
                };
              }
            ];
          };
        in {
          "mahmooz1-${system}" = mkSystem system machineConfigs.mahmooz1;
          "mahmooz1-headless-${system}" = mkSystem system (machineConfigs.mahmooz1 ++ [
            ({ lib, ... }: {
              machine.is_desktop = lib.mkForce false;
            })
          ]);
          "mahmooz2-${system}" = mkSystem system machineConfigs.mahmooz2;
          "mahmooz3-${system}" = mkSystem system machineConfigs.mahmooz3;

          "mahmooz1_iso-${system}" = mkSystem system [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            isobase
            {
              config = {
                boot.loader.efi.canTouchEfiVariables = true;
                machine.name = "mahmooz1";
                machine.is_desktop = true;
                machine.enable_nvidia = false;
                machine.static_ip = "192.168.1.1";
                boot.loader.grub.enable = nixpkgs.lib.mkForce true;
                boot.loader.grub.useOSProber = nixpkgs.lib.mkForce true;
              };
            }
            ./profiles/network-local.nix
          ];
          "server_iso-${system}" = mkSystem system [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            isobase
            {
              config = {
                machine.name = "mahmooz3";
                machine.is_desktop = false;
                machine.enable_nvidia = false;
                boot.loader.grub.enable = nixpkgs.lib.mkForce true;
              };
            }
          ];
        };

        allConfigs = nixpkgs.lib.foldl' (acc: system: acc // (mkConfigsForSystem system)) {} supportedSystems;
      in
        allConfigs // {
          # Default aliases for x86_64 systems
          mahmooz1 = allConfigs."mahmooz1-x86_64-linux";
          mahmooz2 = allConfigs."mahmooz2-x86_64-linux";
          mahmooz3 = allConfigs."mahmooz3-x86_64-linux";
        };
    nixOnDroidConfigurations.droid = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import nixpkgs { system = "aarch64-linux"; };
      modules = [ ./hosts/droid.nix ];
    };

    # development shells for all systems
    devShells = forAllSystems (system: let
      sysPkgs = mkPkgs system;
      isLinux = nixpkgs.lib.hasInfix "linux" system;

      # Python environment shells (work on all systems)
      # NOTE: You must generate uv.lock first:
      #   cd python-envs/tesseract && uv lock --python python3.12
      pythonShells = {
        # Tesseract environment (pytesseract + PIL)
        tesseract = let
          pythonEnv = mkPythonEnv {
            inherit system;
            workspaceRoot = ./python-envs/tesseract;
            envName = "tesseract-venv";
            cudaSupport = false;
          };
        in sysPkgs.mkShell {
          packages = [ pythonEnv ];
        };

        # mlx-lm environment
        mlx-lm = sysPkgs.mkShell {
          packages = [ self.packages.${system}.mlx-lm-env ];
        };

        # ML/CUDA environment (torch, torchvision, etc.)
        # Only works with CUDA support on Linux systems
        ml-cuda = let
          pythonEnv = mkPythonEnv {
            inherit system;
            workspaceRoot = ./python-envs/ml-cuda;
            envName = "ml-cuda-venv";
            cudaSupport = isLinux;  # Enable CUDA only on Linux
          };
        in if isLinux then
          # Full CUDA environment for Linux
          sysPkgs.mkShell {
            packages = [ pythonEnv ];
            env = {
              CUDA_PATH = "${sysPkgs.cudatoolkit}";
              CUDA_HOME = "${sysPkgs.cudatoolkit}";
            };
            shellHook = ''
              export LD_LIBRARY_PATH=/run/opengl-driver/lib
              export TRITON_LIBCUDA_PATH=/run/opengl-driver/lib
              export TRITON_PTXAS_PATH="${sysPkgs.cudatoolkit}/bin/ptxas"
            '';
          }
           else
             # CPU-only environment for non-Linux systems (macOS, etc.)
             sysPkgs.mkShell {
               packages = [ pythonEnv ];
             };

        # mineru = let
        #   pythonEnv = mkPythonEnv {
        #     inherit system;
        #     workspaceRoot = ./python-envs/mineru;
        #     envName = "mineru-venv";
        #     cudaSupport = false;
        #   };
        # in sysPkgs.mkShell {
        #   packages = [ pythonEnv ];
        # };
      };

      # UV shell - works on all systems
      uvShell = sysPkgs.mkShell {
        packages = with sysPkgs; [
          python312
          uv
        ];
        env = {
          UV_PYTHON = sysPkgs.python312.interpreter;
          UV_PYTHON_DOWNLOADS = "never";
          UV_NO_SYNC = "1";
        };
      };

      # mineruEnv = mkPythonEnv {
      #   inherit system;
      #   workspaceRoot = ./python-envs/mineru;
      #   envName = "mineru-venv";
      #   cudaSupport = false;
      # };

      # this is from the nix-determinate tutorial i think, im leaving it here
      defaultShell = if nixpkgs.lib.hasInfix "darwin" system then
        sysPkgs.mkShellNoCC {
          packages = with sysPkgs; [
            (writeShellApplication {
              name = "apply-nix-darwin-configuration";
              runtimeInputs = [
                inputs.nix-darwin.packages.${system}.darwin-rebuild
              ];
              text = ''
                echo "> Applying nix-darwin configuration..."

                echo "> Running darwin-rebuild switch as root..."
                sudo darwin-rebuild switch --flake .
                echo "> darwin-rebuild switch was successful ✅"

                echo "> macOS config was successfully applied 🚀"
              '';
            })
          ] ++ nixpkgs.lib.optional (self ? formatter.${system}) self.formatter.${system};
        } else
          # basic shell for linux and other systems
          sysPkgs.mkShellNoCC {
            packages = [ ];
          };
    in
      # merge all shells together
      pythonShells // {
        uv = uvShell;
        default = defaultShell;
      }
    );
    packages = forAllSystems (system: let
      sysPkgs = mkPkgs system;
      isDarwin = nixpkgs.lib.hasInfix "darwin" system;
      linuxSystem = if nixpkgs.lib.hasInfix "aarch64" system then "aarch64-linux" else "x86_64-linux";
    in {
      mlx-lm-env = mkPythonEnv {
        inherit system;
        workspaceRoot = ./python-envs/mlx-lm;
        envName = "mlx-lm-venv";
        cudaSupport = false;
      };
      vm = (self.nixosConfigurations."mahmooz1-${linuxSystem}".extendModules {
        modules = [
          ({ config, pkgs, lib, ... }: {
            _module.args.hostPkgs = sysPkgs;
            _module.args.hostVoldir =
              if isDarwin
              then self.darwinConfigurations.mahmooz0.config.machine.voldir
              else "/home/mahmooz";
            # VM mode to simplify build
            machine.is_vm = true;
          })
        ];
      }).config.system.build.vm;
      headless-vm = (self.nixosConfigurations."mahmooz1-headless-${linuxSystem}".extendModules {
        modules = [
          ({ config, pkgs, lib, ... }: {
            _module.args.hostPkgs = sysPkgs;
            _module.args.hostVoldir =
              if isDarwin
              then self.darwinConfigurations.mahmooz0.config.machine.voldir
              else "/home/mahmooz";
            # VM mode to simplify build
            machine.is_vm = true;
          })
        ];
      }).config.system.build.vm;
    }
    );

    robotnixConfigurations = {
      # nix build .#robotnixConfigurations.mylineageos.ota.
      "mylineageos" = inputs.robotnix.lib.robotnixSystem ./android/lineageos.nix;
      "mygrapheneos" = inputs.robotnix.lib.robotnixSystem ./android/grapheneos.nix;
    };
    darwinConfigurations = {
      # silicon macs (M1, M2, M3, etc.)
      mahmooz0 =
        let
          system = "aarch64-darwin";
          sysPkgs = mkPkgs system;
          # transformers environment with MPS support for macOS
          mps-transformers = mkPythonEnv {
            inherit system;
            workspaceRoot = ./python-envs/transformers-mps;
            envName = "transformers-mps-venv";
            # should we be enabling cuda support? i think it might be handled differently on macos and might be good to enable
            # cudaSupport = true;
          };
          # mlx-lm environment
          mlx-lm = self.packages.${system}.mlx-lm-env;
        in
          inputs.nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            specialArgs = {
              inherit inputs;
              system = "aarch64-darwin";
              myutils = import ./lib/utils.nix { inherit system; };
            };
            modules = [
              # from https://github.com/cpick/nix-rosetta-builder
              # an existing Linux builder is needed to initially bootstrap `nix-rosetta-builder`.
              # if one isn't already available: comment out the `nix-rosetta-builder` module below,
              # uncomment this `linux-builder` module, and run `darwin-rebuild switch`:
              # { nix.linux-builder.enable = true; }
              # then: uncomment `nix-rosetta-builder`, remove `linux-builder`, and `darwin-rebuild switch`
              # a second time. subsequently, `nix-rosetta-builder` can rebuild itself.
              # also might need 'softwareupdate --install-rosetta --agree-to-license'
              # inputs.nix-rosetta-builder.darwinModules.default

              inputs.determinate.darwinModules.default
              ./profiles/determinate.nix

              inputs.mac-app-util.darwinModules.default
              inputs.home-manager.darwinModules.home-manager
              ({ config, pkgs, lib, ... }: {
                config = {
                  machine.name = "mahmooz0";
                  machine.user = "mahmoodsheikh";
                  machine.is_desktop = true;
                  machine.enable_nvidia = false;
                  machine.is_linux = false;
                  machine.is_darwin = true;
                  machine.static_ip = "192.168.1.1";

                  # add mps-transformers package to system packages
                  environment.systemPackages = [
                    # create a transformers CLI executable
                    (sysPkgs.writeShellScriptBin "mps-transformers" ''
                      exec ${mps-transformers}/bin/transformers "$@"
                    '')
                    (sysPkgs.writeShellScriptBin "mps-python" ''
                      exec ${mps-transformers}/bin/python "$@"
                    '')
                    # mlx-lm scripts
                    (sysPkgs.writeShellScriptBin "uv-mlx-lm-generate" ''
                      exec ${mlx-lm}/bin/mlx_lm.generate "$@"
                    '')
                    (sysPkgs.writeShellScriptBin "uv-mlx-lm-convert" ''
                      exec ${mlx-lm}/bin/mlx_lm.convert "$@"
                    '')
                    (sysPkgs.writeShellScriptBin "uv-mlx-lm-lora" ''
                      exec ${mlx-lm}/bin/mlx_lm.lora "$@"
                    '')
                    (sysPkgs.writeShellScriptBin "uv-mlx-lm-merge" ''
                      exec ${mlx-lm}/bin/mlx_lm.merge "$@"
                    '')
                    (sysPkgs.writeShellScriptBin "uv-mlx-lm-chat" ''
                      exec ${mlx-lm}/bin/mlx_lm.chat "$@"
                    '')
                    (sysPkgs.writeShellScriptBin "uv-mlx-python" ''
                      exec ${mlx-lm}/bin/python "$@"
                    '')
                    (sysPkgs.writeShellScriptBin "uv-mlx-lm-server" ''
                      exec ${mlx-lm}/bin/mlx_lm.server "$@"
                    '')
                    (sysPkgs.writeShellScriptBin "uv-fastmlx" ''
                      exec ${mlx-lm}/bin/fastmlx "$@"
                    '')
                    # VM package - provides run-mahmooz1-vm command
                    self.packages.${system}.vm
                  ];
                };
              })
              ./config-darwin.nix
              ./hosts/mahmooz0.nix
              inputs.nix-homebrew.darwinModules.nix-homebrew
            ];
          };
    };
  };
}