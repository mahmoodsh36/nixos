{ pkgs, lib, config, config', ... }:
{
  config = lib.mkIf config'.machine.is_desktop {
    programs.plasma = {
      enable = config'.machine.enable_plasma;

      workspace = {
        clickItemTo = "open";
        lookAndFeel = "org.kde.breezedark.desktop";
        cursor = {
          theme = "Bibata-Modern-Ice";
          size = 32;
        };
        # iconTheme = "Papirus-Dark";
        wallpaper = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Patak/contents/images/1080x1920.png";
      };

      # hotkeys.commands."launch-konsole" = {
      #   name = "Launch Konsole";
      #   key = "Meta+Alt+K";
      #   command = "konsole";
      # };

      fonts = {
        general = {
          family = "JetBrains Mono";
          pointSize = 12;
        };
      };

      desktop.widgets = [
        {
          plasmusicToolbar = {
            position = {
              horizontal = 51;
              vertical = 100;
            };
            size = {
              width = 250;
              height = 250;
            };
          };
        }
      ];

      panels = [
        {
          location = "bottom";
          widgets = [
            {
              name = "org.kde.plasma.kickoff";
              config = {
                General = {
                  icon = "nix-snowflake-white";
                  alphaSort = true;
                };
              };
            }
            {
              kickoff = {
                sortAlphabetically = true;
                icon = "nix-snowflake-white";
              };
            }
            {
              iconTasks = {
                launchers = [
                  "applications:org.kde.dolphin.desktop"
                  "applications:org.kde.konsole.desktop"
                ];
              };
            }
            {
              name = "org.kde.plasma.icontasks";
              config = {
                General = {
                  launchers = [
                    "applications:org.kde.konsole.desktop"
                  ];
                };
                showOnlyCurrentDesktop = false;
              };
            }
            "org.kde.plasma.marginsseparator"
            {
              digitalClock = {
                calendar.firstDayOfWeek = "sunday";
                time.format = "12h";
              };
            }
            {
              systemTray.items = {
                # we explicitly show bluetooth and battery
                shown = [
                  "org.kde.plasma.battery"
                  "org.kde.plasma.bluetooth"
                ];
                # and explicitly hide networkmanagement and volume
                hidden = [
                  "org.kde.plasma.networkmanagement"
                  "org.kde.plasma.volume"
                ];
              };
            }
          ];
          # hiding = "autohide";
        }
        # application name, global menu and song information and playback controls at the top
        {
          location = "top";
          height = 26;
          widgets = [
            {
              applicationTitleBar = {
                behavior = {
                  activeTaskSource = "activeTask";
                };
                layout = {
                  elements = [ "windowTitle" ];
                  horizontalAlignment = "left";
                  showDisabledElements = "deactivated";
                  verticalAlignment = "center";
                };
                overrideForMaximized.enable = false;
                titleReplacements = [
                  {
                    type = "regexp";
                    originalTitle = "^Brave Web Browser$";
                    newTitle = "Brave";
                  }
                  {
                    type = "regexp";
                    originalTitle = ''\\bDolphin\\b'';
                    newTitle = "File manager";
                  }
                ];
                windowTitle = {
                  font = {
                    bold = false;
                    fit = "fixedSize";
                    size = 12;
                  };
                  hideEmptyTitle = true;
                  margins = {
                    bottom = 0;
                    left = 10;
                    right = 5;
                    top = 0;
                  };
                  source = "appName";
                };
              };
            }
            "org.kde.plasma.appmenu"
            "org.kde.plasma.panelspacer"
            {
              plasmusicToolbar = {
                panelIcon = {
                  albumCover = {
                    useAsIcon = false;
                    radius = 8;
                  };
                  icon = "view-media-track";
                };
                playbackSource = "auto";
                musicControls.showPlaybackControls = true;
                songText = {
                  displayInSeparateLines = true;
                  maximumWidth = 640;
                  scrolling = {
                    behavior = "alwaysScroll";
                    speed = 3;
                  };
                };
              };
            }
          ];
        }
      ];

      window-rules = [
        {
          description = "Dolphin";
          match = {
            window-class = {
              value = "dolphin";
              type = "substring";
            };
            window-types = [ "normal" ];
          };
          apply = {
            noborder = {
              value = true;
              apply = "force";
            };
            # `apply` defaults to "apply-initially"
            maximizehoriz = true;
            maximizevert = true;
          };
        }
      ];

      powerdevil = {
        AC = {
          powerButtonAction = "lockScreen";
          autoSuspend = {
            action = "shutDown";
            # idleTimeout = 1000;
            idleTimeout = 600000;
          };
          turnOffDisplay = {
            idleTimeout = 1000;
            idleTimeoutWhenLocked = "immediately";
          };
        };
        battery = {
          powerButtonAction = "sleep";
          whenSleepingEnter = "standbyThenHibernate";
        };
        lowBattery = {
          whenLaptopLidClosed = "hibernate";
        };
      };

      kwin = {
        edgeBarrier = 0; # disables the edge-barriers introduced in plasma 6.1
        cornerBarrier = false;
        scripts.polonium.enable = true;
      };

      # kscreenlocker = {
      #   lockOnResume = true;
      #   timeout = 10;
      # };

      shortcuts = {
        # ksmserver = {
        #   "Lock Session" = [
        #     "Screensaver"
        #     "Meta+Ctrl+Alt+L"
        #   ];
        # };

        kwin = {
          "Expose" = "Meta+,";
          "Switch Window Down" = "Meta+J";
          "Switch Window Left" = "Meta+H";
          "Switch Window Right" = "Meta+L";
          "Switch Window Up" = "Meta+K";
          "Switch to Desktop 1" = "Meta+1";
          "Switch to Desktop 2" = "Meta+2";
          "Switch to Desktop 3" = "Meta+3";
          "Switch to Desktop 4" = "Meta+4";
          "Window to Desktop 1" = "Meta+Shift+1";
          "Window to Desktop 2" = "Meta+Shift+2";
          "Window to Desktop 3" = "Meta+Shift+3";
          "Window to Desktop 4" = "Meta+Shift+4";
          "Overview" = "Meta+W";
          "Window Close" = "Meta+q";
        };
      };

      configFile = {
        baloofilerc."Basic Settings"."Indexing-Enabled" = false;

        kwinrc."org.kde.kdecoration2".ButtonsOnLeft = "SF";
        "kwinrc"."Effect-blurplus"."BlurMenus" = true;
        "kwinrc"."Effect-blurplus"."BlurStrength" = 8;
        "kwinrc"."Effect-blurplus"."TopCornerRadius" = 2;
        "kwinbottomrc"."Effect-blurplus"."DockCornerRadius" = 2;
        "kwinrc"."Effect-blurplus"."MenuCornerRadius" = 2;

        "kdeglobals"."General"."AllowKDEAppsToRememberWindowPositions" = true;
        "kdeglobals"."KDE"."SingleClick" = true;
        "kdeglobals"."KFileDialog Settings"."Show Bookmarks" = false;
        "kdeglobals"."KFileDialog Settings"."Show Full Path" = true;
        "kdeglobals"."KFileDialog Settings"."Show Inline Previews" = true;
        "kdeglobals"."KFileDialog Settings"."Show Preview" = true;
        "kdeglobals"."KFileDialog Settings"."Show hidden files" = true;
        "kdeglobals"."KFileDialog Settings"."Sort hidden files last" = true;
        "kwalletrc"."Wallet"."First Use" = false;

        "kwinrc"."Desktops"."Rows" = 1;
        kwinrc.Desktops.Number = {
          value = 4;
          # forces kde to not change this value (even through the settings app).
          immutable = true;
        };
        kscreenlockerrc = {
          Greeter.WallpaperPlugin = "org.kde.potd";
          # to use nested groups use / as a separator. in the below example,
          # provider will be added to [greeter][wallpaper][org.kde.potd][general].
          "Greeter/Wallpaper/org.kde.potd/General".Provider = "bing";
        };
      };
    };
  };
}