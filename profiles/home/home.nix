{ lib, config, pkgs, inputs, pkgs-master, pkgs-unstable, ... }:

let
  constants = (import ../lib/constants.nix);
  # here, config' is the system config, while "config" might be home-manager-specific
  config' = config;
in
{
  imports = [
  ];

  config = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "hmbkup";
    home-manager.extraSpecialArgs = { inherit pkgs pkgs-master pkgs-unstable inputs; };
    home-manager.sharedModules = lib.mkIf config.machine.is_linux [
      inputs.plasma-manager.homeModules.plasma-manager
    ];

    # "lib" in home-manager configs needs to not be overridden. otherwise
    # we might cause issues
    home-manager.users.mahmooz = { lib, config, ... }:
      let
        dots = if builtins.pathExists "${config.home.homeDirectory}/work/otherdots"
               then "${config.home.homeDirectory}/work/otherdots"
               else (builtins.fetchGit {
                 url = "${constants.mygithub}/otherdots.git";
                 ref = "main";
               }).outPath;

        nvim_dots = if builtins.pathExists "${config.home.homeDirectory}/work/nvim"
                    then "${config.home.homeDirectory}/work/nvim"
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

        scripts_dir = if builtins.pathExists "${config.home.homeDirectory}/work/scripts"
                      then "${config.home.homeDirectory}/work/scripts"
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