{
  pkgs,
  inputs,
  lib,
  config',
  ...
}: let
  extensions = inputs.nix-vscode-extensions.extensions.${pkgs.system};
in {
  config = lib.mkIf (config'.machine.is_desktop && !config'.machine.low_resources) {
    programs.vscode = {
      enable = true;
      package = pkgs.vscode;
      # package = pkgs.windsurf;
      profiles.default.enableExtensionUpdateCheck = false;
      profiles.default.enableUpdateCheck = false;
      profiles.default.extensions = with pkgs.vscode-extensions; [
        jdinhlife.gruvbox
        bbenoist.nix
        esbenp.prettier-vscode
        hediet.vscode-drawio
        james-yu.latex-workshop
        ms-python.python
        ms-toolsai.jupyter
        ms-toolsai.jupyter-keymap
        ms-toolsai.jupyter-renderers
        ms-toolsai.vscode-jupyter-slideshow
        ms-toolsai.vscode-jupyter-cell-tags
        redhat.vscode-yaml
        vscodevim.vim
        file-icons.file-icons
        yzhang.markdown-all-in-one
      ];
      profiles.default.userSettings = {
        "files.insertFinalNewline" = false;
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
        "continue.telemetryEnabled" = false;
        "editor.fontLigatures" = true;
        "editor.quickSuggestions" = {
          "other" = true;
          "comments" = false;
          "strings" = true;
        };
        # "terminal.integrated.defaultProfile.linux" = "zsh";
        "editor.guides.bracketPairs" = "active";
        # "windsurf.autoExecutionPolicy" = "off";
        "windsurf.autocompleteSpeed" = "default";
        # "windsurf.chatFontSize" = "default";
        "windsurf.explainAndFixInCurrentConversation" = true;
        "windsurf.openRecentConversation" = true;
        "windsurf.rememberLastModelSelection" = true;
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