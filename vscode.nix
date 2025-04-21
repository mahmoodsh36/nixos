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
    home.file.".continue/config.json".text = builtins.toJSON {
      models = [
        {
          title = "mymodel";
          provider = "llama.cpp";
          # provider = "openai";
          model = "final-THUDM--GLM-Z1-32B-0414.gguf";
          apiBase = "http://mahmooz2:5000";
          # useLegacyCompletionsEndpoint = false;
        }
      ];
      tabAutocompleteModel = {
        title = "mymodel";
        provider = "llama.cpp";
        model = "final-THUDM--GLM-Z1-32B-0414.gguf";
        apiBase = "http://mahmooz2:5000";
        # useLegacyCompletionsEndpoint = false;
      };
      # tabAutocompleteOptions = {
      #   useLegacyCompletionsEndpoint = false;
      # };
      # embeddingsProvider = {
      #   provider = "llama.cpp";
      #   model = "nomic-embed-text";
      # };
    };
    programs.vscode = {
      enable = true;
      package = pkgs.vscode;
      # package = pkgs.windsurf;
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
        continue.continue
        rooveterinaryinc.roo-cline
        julialang.language-julia
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