{ pkgs, lib, pkgs-pinned, config, ... }:

{
  imports = [
    ./mcp-servers.nix
  ];

  config = lib.mkIf config.machine.is_desktop {
    programs.zed-editor = {
      enable = true;
      # package = pkgs-pinned.zed-editor;
      extensions = ["nix" "toml" "make"];
      # userKeymaps = [
      #   {
      #     "context" = "Workspace";
      #     "bindings" = {
      #       "ctrl-s" = "file::Save";
      #     };
      #   }
      # ];
      userSettings = {
        # this wont work because we need to unpack the "mcpServers" attr
        language_models = {
          openai = {
            api_url = "http://mahmooz2:5000";
            available_models = [{
              name = "qwq:32b";
              display_name = "qwq 32b";
              max_tokens = 32768;
            }];
          };
        };
        assistant = {
          enabled = true;
          version = "1";
          default_open_ai_model = null;
          default_model = {
            provider = "openai";
            model = "qwq:32b";
          };
          node = {
            path = lib.getExe pkgs.nodejs;
            npm_path = lib.getExe' pkgs.nodejs "npm";
          };
        };
        hour_format = "hour24";
        auto_update = false;
        terminal = {
          # alternate_scroll = "off";
          blinking = "off";
          # copy_on_select = false;
          dock = "bottom";
          detect_venv = {
            on = {
              directories = [".env" "env" ".venv" "venv"];
              activate_script = "default";
            };
          };
          env = {
            TERM = "wezterm";
          };
          font_family = "FiraCode Nerd Font";
          font_features = null;
          font_size = null;
          line_height = "comfortable";
          option_as_meta = false;
          button = false;
          shell = "system";
          toolbar = {
            title = true;
          };
          working_directory = "current_project_directory";
        };
        lsp = {
          # pyright = {
          #   settings = {
          #     python.analysis = {
          #       diagnosticMode = "workspace";
          #       typeCheckingMode = "strict";
          #     };
          #     python = {
          #       pythonPath = ".venv/bin/python";
          #     };
          #   };
          # };
          nix = {
            binary = {
              path_lookup = true;
            };
          };
        };
        languages = {
          C = {
            format_on_save = "off";
            preferred_line_length = 64;
            soft_wrap = "preferred_line_length";
          };
          JSON = {
            tab_size = 4;
          };
          "Elixir" = {
            language_servers = ["!lexical" "elixir-ls" "!next-ls"];
            format_on_save = {
              external = {
                command = "mix";
                arguments = ["format" "--stdin-filename" "{buffer_path}" "-"];
              };
            };
          };
        };
        vim_mode = true;
        # tell zed to use direnv and direnv can use a flake.nix enviroment.
        load_direnv = "shell_hook";
        base_keymap = "VSCode";
        theme = {
          mode = "dark";
          light = "One Light";
          dark = "Gruvbox Dark";
        };
        show_whitespaces = "all";
        ui_font_size = 16;
        buffer_font_size = 16;
        tab_bar = {
          show = true;
          show_nav_history_buttons = true;
          show_tab_bar_buttons = true;
        };
        format_on_save = "off";
        diagnostics = {
          inline = {
            enabled = true;
            update_debounce_ms = 150;
            padding = 4;
            min_column = 0;
            max_severity = null;
          };
        };
        git = {
          git_gutter = "tracked_files";
          inline_blame = {
            enabled = true;
          };
          hunk_style = "staged_hollow";
        };
        indent_guides = {
          enabled = true;
          coloring = "indent_aware";
          background_coloring = "indent_aware";
        };
      };
    };
  };
}