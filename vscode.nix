{
  pkgs,
  inputs,
  lib,
  config,
  ...
}: let
  extensions = inputs.nix-vscode-extensions.extensions.${pkgs.system};
in {
  config = lib.mkIf config.machine.is_desktop {
    programs.vscode = {
      enable = true;
      package = pkgs.vscode;
      profiles.default.enableExtensionUpdateCheck = false;
      profiles.default.enableUpdateCheck = false;
      # extensions = with extensions.vscode-marketplace; [
      profiles.default.extensions = with pkgs.vscode-extensions; [
        jdinhlife.gruvbox
        bbenoist.nix
        esbenp.prettier-vscode
        github.copilot
        github.copilot-chat
        hediet.vscode-drawio
        james-yu.latex-workshop
        # ms-python.python
        ms-toolsai.jupyter
        ms-toolsai.jupyter-keymap
        ms-toolsai.jupyter-renderers
        ms-toolsai.vscode-jupyter-slideshow
        ms-toolsai.vscode-jupyter-cell-tags
        ms-vsliveshare.vsliveshare
        redhat.vscode-yaml
        vscodevim.vim
        file-icons.file-icons
      ];
      profiles.default.userSettings = {
        "editor.wordWrap" = "on";
        "workbench.startupEditor" = "newUntitledFile";
        "files.autoSave" = "afterDelay";
        # "python.autoComplete.extraPaths" = [];
        "editor.lineNumbers" = "on";
        "vim.commandLineModeKeyBindings" = [];
        "vim.useSystemClipboard" = true;
        "explorer.confirmDragAndDrop" = false;
        "security.workspace.trust.enabled" = false;
        # "jupyter.askForKernelRestart" = false;
      };
      profiles.default.keybindings = [
        # {
        #   "key" = "ctrl+k";
        #   "command" = "-extension.vim_ctrl+k";
        #   "when" = "editorTextFocus && vim.active && vim.use<C-k> && !inDebugRepl";
        # }
      ];
    };
  };
}