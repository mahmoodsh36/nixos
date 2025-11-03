{ lib, config, pkgs, inputs, pkgs-master, pkgs-unstable, ... }:

let
  constants = (import ../../lib/constants.nix);
  # here, config' is the system config, while "config" might be home-manager-specific
  config' = config;
  homedir = if config.machine.is_darwin
             then "/Users/${config.machine.user}"
             else "/home/${config.machine.user}";
  voldir = if config.machine.is_darwin
           then "/Volumes/main"
           else "/home/${config.machine.user}";
  work_dir = "${homedir}/work";
in
{
  imports = [
  ];

  config = {
    users.users."${config.machine.user}" = {
      shell = pkgs.zsh;
      home = homedir;
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "hmbkup";
    home-manager.extraSpecialArgs = { inherit pkgs pkgs-master pkgs-unstable inputs; };
    home-manager.sharedModules = lib.mkIf config.machine.is_linux [
      inputs.plasma-manager.homeModules.plasma-manager
    ];

    # "lib" in home-manager configs needs to not be overridden. otherwise
    # we might cause issues
    home-manager.users."${config.machine.user}" = { lib, config, ... }:
      let
        dots = if builtins.pathExists "${work_dir}/otherdots"
               then "${work_dir}/otherdots"
               else (builtins.fetchGit {
                 url = "${constants.mygithub}/otherdots.git";
                 ref = "main";
               }).outPath;

        nvim_dots = if builtins.pathExists "${work_dir}/nvim"
                    then "${work_dir}/nvim"
                    else (builtins.fetchGit {
                      url = "${constants.mygithub}/nvim.git";
                      ref = "main";
                    }).outPath;

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
                      else (builtins.fetchGit {
                        url = "${constants.mygithub}/scripts.git";
                        ref = "main";
                      }).outPath;
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
      in {
        _module.args = {
          config' = config';
        };

        /* the home.stateVersion option does not have a default and must be set */
        home.stateVersion = "24.05";

        imports = [
          ./home-desktop.nix
          ../../modules/machine-options.nix
          ../machine-config.nix
          ./vscode.nix
          ./zed.nix
          # ./plasma.nix
          ./python.nix
          # ./julia.nix
          ./sbcl.nix
          ./distrobox-config.nix
        ];

        home.file = config_entries // script_entries // {
          ".zshrc" = {
            source = config.lib.file.mkOutOfStoreSymlink "${dots}/.zshrc";
          };
          ".zprofile" = {
            source = config.lib.file.mkOutOfStoreSymlink "${dots}/.zprofile";
          };
          ".config/nvim" = {
            source = config.lib.file.mkOutOfStoreSymlink nvim_dots;
          };
        };

        home.sessionVariables = rec {
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
          BRAIN_DIR = "${HOME_DIR}/brain";
          MUSIC_DIR = "${HOME_DIR}/music";
          WORK_DIR = work_dir;
          VOLUME_DIR = voldir;
          NOTES_DIR = "${BRAIN_DIR}/notes";
          SCRIPTS_DIR = "${WORK_DIR}/scripts";
          DOTFILES_DIR = "${WORK_DIR}/otherdots";
          NIX_CONFIG_DIR = "${WORK_DIR}/nixos";
          BLOG_DIR = "${WORK_DIR}/blog";
          EDITOR = "nvim";
          BROWSER = "firefox";
          DATA_DIR = "${HOME_DIR}/data";
          MPV_SOCKET_DIR = "${DATA_DIR}/mpv_data/sockets";
          MPV_MAIN_SOCKET_PATH = "${DATA_DIR}/mpv_data/sockets/mpv.socket";
          MYGITHUB = constants.mygithub;
          PERSONAL_WEBSITE = constants.personal_website;
          MAHMOOZ3_ADDR = constants.mahmooz3_addr;
          MAHMOOZ2_ADDR = constants.mahmooz2_addr;
          MAHMOOZ1_ADDR = constants.mahmooz1_addr;
          MYDOMAIN = constants.mydomain;
          # LLAMA_CACHE = lib.mkIf (builtins.pathExists constants.models_dir) constants.models_dir;
        };

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
      };
  };
}
