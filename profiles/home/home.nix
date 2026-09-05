{ lib, config, pkgs, inputs, pkgs-unstable, pkgs-pinned, ... }:

let
  constants = (import ../../lib/constants.nix);
  # here, config' is the system config, while "config" might be home-manager-specific
  config' = config;
  homedir = if config.machine.is_darwin
             then "/Users/${config.machine.user}"
             else "/home/${config.machine.user}";
  voldir = config.machine.voldir;
  work_dir = "${config.machine.voldir}/work";
  # ssot for shell env vars.
  sessionVars = rec {
    PYTHON_HISTORY = "${homedir}/brain/python_history";
    HOME_DIR = homedir;
    VOL_DIR = voldir;
    BRAIN_DIR = "${VOL_DIR}/brain";
    MUSIC_DIR = "${VOL_DIR}/music";
    WORK_DIR = work_dir;
    work = WORK_DIR;
    mahmooz4 = constants.mahmooz4_addr;
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
    MAHMOOZ4_ADDR = constants.mahmooz4_addr;
    MYDOMAIN = constants.mydomain;
  };
  sessionVarsExports = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (n: v: ''export ${n}="${toString v}"'') sessionVars);
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
    home-manager.extraSpecialArgs = { inherit pkgs pkgs-unstable pkgs-pinned inputs; };
    home-manager.sharedModules = [
    ] ++ pkgs.lib.optionals config.machine.is_linux  [
      inputs.plasma-manager.homeModules.plasma-manager
      inputs.niri-flake.homeModules.niri
    ] ++ pkgs.lib.optionals config.machine.is_darwin  [
      inputs.mac-app-util.homeManagerModules.default
    ];

    # "lib" in home-manager configs needs to not be overridden. otherwise
    # we might cause issues
    home-manager.users."${config.machine.user}" = { lib, config, ... }:
      let
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
          ../../services/podman-autobuilder.nix
        ];

        # symlink to live $work repository if it exists at runtime,
        # otherwise fall back to the flake input from the nix store.
        home.activation.linkDotfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          link_or_fallback() {
            local target="$1"
            local live_path="$2"
            local store_path="$3"

            mkdir -p "$(dirname "$target")"
            if [ -e "$live_path" ]; then
              $DRY_RUN_CMD ln -sfn "$live_path" "$target"
            elif [ -e "$store_path" ]; then
              $DRY_RUN_CMD ln -sfn "$store_path" "$target"
            fi
          }

          link_dir_contents() {
            local live_dir="$1"
            local store_dir="$2"
            local dest_dir="$3"
            local filter_ext="$4"

            mkdir -p "$dest_dir"
            local src_dir="$store_dir"
            if [ -d "$live_dir" ]; then
              src_dir="$live_dir"
            fi

            for f in "$src_dir"/*; do
              [ -e "$f" ] || continue
              local fname=$(basename "$f")
              # ~/.local/bin takes only runnable scripts
              if [ -n "$filter_ext" ]; then
                case "$fname" in
                  *.py|*.sh|*.el|*.lua) ;;
                  *) continue ;;
                esac
              fi
              $DRY_RUN_CMD ln -sfn "$f" "$dest_dir/$fname"
            done
          }

          link_dir_contents "${work_dir}/otherdots/.config" "${inputs.otherdots}/.config" "$HOME/.config" ""

          link_or_fallback "$HOME/.zshrc.manual" "${work_dir}/otherdots/.zshrc" "${inputs.otherdots}/.zshrc"
          link_or_fallback "$HOME/.zprofile.manual" "${work_dir}/otherdots/.zprofile" "${inputs.otherdots}/.zprofile"
          link_or_fallback "$HOME/.gitconfig" "${work_dir}/otherdots/.gitconfig" "${inputs.otherdots}/.gitconfig"
          link_or_fallback "$HOME/.config/nvim" "${work_dir}/nvim" "${inputs.nvim}"

          link_dir_contents "${work_dir}/scripts" "${inputs.scripts}" "$HOME/.local/bin" "filter"

          # dynamically scan live $work/emacs.d if present, otherwise use flake input
          link_dir_contents "${work_dir}/emacs.d" "${inputs.emacs-d}" "$HOME/.emacs.d" ""

          link_dir_contents "${work_dir}/lem-config" "${inputs.lem-config}" "$HOME/.lem" ""
        '';

        programs.zsh = {
          enable = true;
          # https://github.com/nix-community/home-manager/issues/7633
          # we use a custom .zshrc.manual to avoid issues
          initContent = lib.mkOrder 1500 ''
            source ~/.zshrc.manual
          '';
          profileExtra = ''
            [ -f ~/.zprofile.manual ] && source ~/.zprofile.manual
          '';
          envExtra = sessionVarsExports;
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
          sessionVariables = sessionVars;
        };

        programs.atuin = {
          enable = !config'.machine.is_vm;
          flags = [
            "--disable-up-arrow"
          ];
          settings = {
            auto_sync = false;
            update_check = false;
            # show_preview = true;
            sync_frequency = "5m";
            # style = "full";
            # sync_address = "https://api.atuin.sh";
            search_mode = "fuzzy";
            db_path = "$DATA_DIR/atuin/history.db";
            record_store_path = "$DATA_DIR/atuin/records.db";
            key_path = "$DATA_DIR/atuin/key";
          };
        };

        programs.home-manager.enable = true;

        programs.neovim = {
          enable = true;
          sideloadInitLua = true;
          plugins = lib.optionals (!config'.machine.low_resources) (with pkgs.vimPlugins; [
            nvim-treesitter.withAllGrammars
          ]);
          viAlias = true;
          vimAlias = true;
          vimdiffAlias = true;
          withNodeJs = !config'.machine.low_resources;
          withPython3 = !config'.machine.low_resources;
        };

        home.packages = with pkgs; [
        ] ++ lib.optionals config'.machine.is_linux [
          pkgs.dconf
        ];

        programs.git = {
          enable = true;
          settings.user = {
            name = "mahmoodsh36";
            email = "mahmod.m2015@gmail.com";
          };
        };

        services.podman-autobuilder = {
          enable = config'.machine.can_compile;
          podmanPackage = config'.machine.podman.pkg;
          containers = {
            demo = {
              enable = false;
              imageName = "demo:latest";
              context = ../../containers/demo;
              buildArgs = [ "GREETING=hello from the demo" ];
              runArgs = [ "-p" "127.0.0.1:8080:80" ];
              command = [ "httpd" "-f" "-p" "80" "-h" "/www" ];
              execServices = {
                demo-greeting = { command = [ "cat" "/www/index.html" ]; };
              };
              aliases = {
                demo-shell = {
                  command = [ "sh" ];
                  interactive = true;
                };
              };
            };
          };

          composeFiles = {
            demo-compose = {
              enable = false;
              composeFile = ../../containers/demo/compose.yaml;
              workingDirectory = ../../containers/demo;
              environment = { TAG = "latest"; };
            };
          };
        };
      };
  };
}