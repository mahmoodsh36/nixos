{
  pkgs,
  inputs,
  ...
}: let
  extensions = inputs.nix-vscode-extensions.extensions.${pkgs.system};
in {
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    enableExtensionUpdateCheck = false;
    enableUpdateCheck = false;
    # extensions = with extensions.vscode-marketplace; [
    extensions = with pkgs.vscode-extensions; [
      jdinhlife.gruvbox
      bbenoist.nix
      esbenp.prettier-vscode
      github.copilot
      github.copilot-chat
      hediet.vscode-drawio
      james-yu.latex-workshop
      ms-python.python
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
    userSettings = {
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
    keybindings = [
      # {
      #   "key" = "ctrl+k";
      #   "command" = "-extension.vim_ctrl+k";
      #   "when" = "editorTextFocus && vim.active && vim.use<C-k> && !inDebugRepl";
      # }
    ];
  };
}