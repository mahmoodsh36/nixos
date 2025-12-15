{ pkgs, lib, config, config', ... }:

{
  config = lib.mkIf config'.machine.is_darwin {
    home.packages = with pkgs; [
      antigravity
      google-chrome
    ];

    home.sessionVariables = {
      CHROME_BIN = "${pkgs.google-chrome}/bin/google-chrome-stable";
    };

    xdg.configFile = {
      "Antigravity/User/settings.json".text = builtins.toJSON {
        "antigravity.autocompleteSpeed" = "fast";
        "antigravity.autoExecutionPolicy" = "off";
        "antigravity.browserCDPPort" = 9222;
        "antigravity.browserUserProfilePath" = "${config.home.homeDirectory}/.gemini/antigravity-browser-profile";
        "antigravity.chatFontSize" = "default";
        "antigravity.chromeBinaryPath" = "${pkgs.google-chrome}/bin/google-chrome-stable";
        "antigravity.explainAndFixInCurrentConversation" = true;
        "antigravity.marketplaceExtensionGalleryServiceURL" = "https://marketplace.visualstudio.com/_apis/public/gallery";
        "antigravity.marketplaceExtensionGallerySource" = "https://marketplace.visualstudio.com/_apis/public/gallery";
        "antigravity.marketplaceGalleryItemURL" = "https://marketplace.visualstudio.com/items";
        "antigravity.openRecentConversation" = true;
        "antigravity.rememberLastModelSelection" = true;
        "diffEditor.wordWrap" = "off";
        "editor.guides.bracketPairs" = false;
        "editor.guides.indentation" = false;
        "editor.inlayHints.enabled" = "off";
        "editor.wordWrap" = "off";
        "explorer.confirmDelete" = false;
        "explorer.confirmDragAndDrop" = false;
        "git.confirmSync" = false;
        "keyboard.dispatch" = "keyCode";
        "nix.serverPath" = "";
        "terminal.integrated.defaultProfile.linux" = "bash";

        "terminal.integrated.profiles.osx" = {
          "bash" = {
            "path" = "bash";
            "args" = ["-l"];
          };
        };
        "terminal.integrated.defaultProfile.osx" = "bash";
        "terminal.integrated.automationProfile.linux" = {
          "path" = "bash";
          "args" = ["-l"];
        };

        "window.menuBarVisibility" = "compact";
        "workbench.activityBar.location" = "top";
        "workbench.colorCustomizations" = {
          "editor.lineHighlightBackground" = "#1073cf2d";
          "editor.lineHighlightBorder" = "#9fced11f";
        };
        "workbench.colorTheme" = "base24-catppuccin-frappe";
        "workbench.iconTheme" = "gruvbox-material-icon-theme";
        "workbench.layoutControl.enabled" = false;
        "workbench.productIconTheme" = "material-product-icons";
        "workbench.sideBar.location" = "right";

        # extension settings
        "blockman.n04Sub02ColorComboPresetForLightTheme" = "none";
        "blockman.n04Sub05MinDistanceBetweenRightSideEdges" = 2;
        "blockman.n05CustomColorOfDepth0" = "linear-gradient(to right, rgb(19,26,31), rgb(39,46,51))";
        "blockman.n06CustomColorOfDepth1" = "linear-gradient(to right, rgb(19,26,31), rgb(39,46,51))";
        "blockman.n07CustomColorOfDepth2" = "linear-gradient(to right, rgb(19,26,31), rgb(39,46,51))";
        "blockman.n08CustomColorOfDepth3" = "linear-gradient(to right, rgb(19,26,31), rgb(39,46,51))";
        "blockman.n09CustomColorOfDepth4" = "linear-gradient(to right, rgb(19,26,31), rgb(39,46,51))";
        "blockman.n10CustomColorOfDepth5" = "linear-gradient(to right, rgb(19,26,31), rgb(39,46,51))";
        "blockman.n11CustomColorOfDepth6" = "linear-gradient(to right, rgb(19,26,31), rgb(39,46,51))";
        "blockman.n12CustomColorOfDepth7" = "linear-gradient(to right, rgb(19,26,31), rgb(39,46,51))";
        "blockman.n13CustomColorOfDepth8" = "linear-gradient(to right, rgb(19,26,31), rgb(39,46,51))";
        "blockman.n14CustomColorOfDepth9" = "linear-gradient(to right, rgb(19,26,31), rgb(39,46,51))";
        "blockman.n15CustomColorOfDepth10" = "linear-gradient(to right, rgb(19,26,31), rgb(39,46,51))";
        "blockman.n17CustomColorOfFocusedBlock" = "none";
        "blockman.n18CustomColorOfFocusedBlockBorder" = "linear-gradient(to right, #859289, rgb(39,46,51))";
        "blockman.n23AnalyzeSquareBrackets" = true;
        "blockman.n27AlsoRenderBlocksInsideSingleLineAreas" = true;
        "blockman.n28TimeToWaitBeforeRerenderAfterLastChangeEvent" = 0.5;
        "blockman.n31RenderIncrementBeforeAndAfterVisibleRange" = 100;
        "blockman.n33A01B1FromDepth0ToInwardForAllBorders" = "!10,0,0,0; linear-gradient(to right, rgb(19,26,31), rgb(39,46,51)) > linear-gradient(to right, rgb(19,26,31), rgb(39,46,51)) > linear-gradient(to right, rgb(19,26,31), rgb(39,46,51)) > linear-gradient(to right, rgb(19,26,31), rgb(39,46,51)) > linear-gradient(to right, rgb(19,26,31), rgb(39,46,51)) > linear-gradient(to right, rgb(19,26,31), rgb(39,46,51)) > linear-gradient(to right, rgb(19,26,31), rgb(39,46,51)) > linear-gradient(to right, rgb(19,26,31), rgb(39,46,51)) > linear-gradient(to right, rgb(19,26,31), rgb(39,46,51)) > linear-gradient(to right, rgb(19,26,31), rgb(39,46,51)) >";
        "blockman.n33A01B2FromDepth0ToInwardForAllBackgrounds" = "10,0,0,0; none > none > none > none > none > none > none > none > none > none";
        "blockman.n33A04B1FromFocusToOutwardForFocusTreeBorders" = "!40,0,0,0; basic";
        "color-highlight.languages" = [
          "*"
          "css"
          "html"
          "javascript"
          "json"
          "nix"
        ];
      };
    };

    home.file = {
      ".antigravity/argv.json".text = builtins.toJSON {
        "disable-hardware-acceleration" = false;
        "enable-crash-reporter" = false;
      };
    };
  };
}