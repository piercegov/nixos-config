{
  description = "NixOS + Home Manager + Hyprland (NVidia open module) + Lanzaboote";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Hyprland upstream flake to keep hyprland + xdp-hyprland in sync
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";

    # (Optional) Zen browser
    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    # Lanzaboote (Secure Boot)
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, hyprland, zen-browser, lanzaboote, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix

        home-manager.nixosModules.home-manager
        lanzaboote.nixosModules.lanzaboote

        # Wire Hyprland packages from upstream flake and Home Manager config
        ({ lib, pkgs, ... }: {
          nixpkgs.config.allowUnfree = true;

          # Lanzaboote replaces systemd-boot
          boot.loader.systemd-boot.enable = lib.mkForce false;
          boot.lanzaboote = {
            enable = true;
            pkiBundle = "/var/lib/sbctl";
          };

          # Use upstream Hyprland + XDP-Hyprland
          programs.hyprland = {
            enable = true;
            withUWSM = true;
            xwayland.enable = true;
            package = hyprland.packages.${system}.hyprland;
            portalPackage = hyprland.packages.${system}.xdg-desktop-portal-hyprland;
          };

          # Home Manager
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-bak";

          home-manager.users.pierce = { config, pkgs, ... }: {
            home.stateVersion = "24.11";

            # Shell + basics
            programs.zsh = {
              enable = true;
              enableCompletion = true;
              autosuggestion.enable = true;
              syntaxHighlighting.enable = true;
              shellAliases = { ll = "eza -lah"; gs = "git status -sb"; v = "nvim"; };
              initContent = ''
                export EDITOR=nvim
                bindkey -e
              '';
            };

            programs.direnv.enable = true;
            programs.direnv.nix-direnv.enable = true;

            programs.git = {
              enable = true;
              userName = "Pierce Governale";
              userEmail = "piercegovernale@gmail.com";
            };

            programs.zoxide.enable = true;

            # Desktop apps & tools for Hyprland
            home.packages = with pkgs; [
              ripgrep fd tree jq fzf bat eza zoxide just
              wl-clipboard grim slurp wofi
              hyprpicker hyprsysteminfo
              pavucontrol playerctl
              rustup
              (zen-browser.packages.${system}.zen-browser)
              # themes/fonts
              papirus-icon-theme catppuccin-gtk
              nerd-fonts.fira-code nerd-fonts.jetbrains-mono

              # (optional) keep the agent available in PATH (service below uses the store path)
              hyprpolkitagent
            ];

            # GTK theme + icons (Catppuccin + Papirus)
            gtk = {
              enable = true;
              theme = {
                name = "Catppuccin-Mocha-Standard-Blue-Dark";
                package = pkgs.catppuccin-gtk.override {
                  accents = [ "blue" ];
                  size = "standard";
                  variant = "mocha";
                };
              };
              iconTheme = {
                name = "Papirus-Dark";
                package = pkgs.papirus-icon-theme;
              };
            };

            # Cursor (optional)
            home.pointerCursor = {
              gtk.enable = true;
              package = pkgs.bibata-cursors;
              name = "Bibata-Modern-Ice";
              size = 24;
            };

            # Waybar — clean, icon-based, spaced; starts with the session (UWSM)
            programs.waybar = {
              enable = true;
              systemd = {
                enable = true;
                target = "graphical-session.target";
              };
              settings = {
                mainBar = {
                  layer = "top";
                  position = "top";
                  height = 32;
                  margin = "6px 10px 0 10px";
                  spacing = 8;

                  modules-left = [ "hyprland/workspaces" "hyprland/window" ];
                  modules-center = [ ];
                  modules-right = [ "pulseaudio" "pulseaudio#mic" "network" "clock" "tray" ];

                  # Hyprland
                  "hyprland/workspaces" = {
                    format = "{icon}";
                    # Show 1..10 as small circles; active filled
                    format-icons = {
                      "1" = ""; "2" = ""; "3" = ""; "4" = ""; "5" = "";
                      "6" = ""; "7" = ""; "8" = ""; "9" = ""; "10" = "";
                      "default" = "";
                    };
                    persistent-workspaces = { "*" = 5; };
                  };
                  "hyprland/window" = { max-length = 60; separate-outputs = true; };

                  # Audio (uses PipeWire via pipewire-pulse; no PulseAudio daemon needed)
                  pulseaudio = {
                    format = "{icon} {volume:2}%";
                    format-muted = "󰝟  mute";
                    format-icons = { default = [ "󰕿" "󰖀" "󰕾" ]; headphones = "󰋋"; };
                    on-click = "pavucontrol";
                    on-scroll-up   = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
                    on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
                    tooltip = false;
                  };
                  "pulseaudio#mic" = {
                    format = "󰍬 {volume}%";
                    format-muted = "󰍭  mute";
                    on-click = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
                    on-scroll-up   = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SOURCE@ 5%+";
                    on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-";
                    tooltip = false;
                  };

                  # Network
                  network = {
                    format-wifi = "󰖩  {signalStrength}%";
                    format-ethernet = "󰈀";
                    format-disconnected = "󰖪";
                    tooltip = false;
                  };

                  # Time
                  clock = {
                    format = "󰥔  {:%a %b %d  %H:%M}";
                    tooltip = false;
                  };

                  tray = { icon-size = 16; spacing = 8; };
                };
              };

              # Catppuccin-like styling with real spacing
              style = ''
                * {
                  font-family: "JetBrainsMono Nerd Font", "FiraCode Nerd Font", sans-serif;
                  font-size: 12px;
                  min-height: 0;
                }
                window#waybar {
                  background: rgba(24, 24, 37, 0.78);
                  color: #cdd6f4;
                }
                #workspaces button {
                  padding: 0 10px;
                  margin: 4px 6px;
                  border-radius: 8px;
                  background: transparent;
                  color: #a6adc8;
                }
                #workspaces button.active {
                  background: #89b4fa;
                  color: #1e1e2e;
                  font-weight: 600;
                }
                #workspaces button:hover {
                  background: rgba(137,180,250,0.25);
                }
                #window, #pulseaudio, #pulseaudio.muted, #network, #clock, #tray, #battery {
                  padding: 0 10px;
                  margin: 4px 6px;
                  border-radius: 8px;
                  background: rgba(30, 30, 46, 0.6);
                }
                #tray { margin-right: 10px; }
              '';
            };

            # Notification daemon
            services.swaync.enable = true;

            # nm-applet as a user service
            services.network-manager-applet.enable = true;

            # Hyprpaper as a user service with declarative config
            services.hyprpaper = {
              enable = true;
              settings = {
                splash = false;
                ipc = "on";
                preload = [
                  "${config.home.homeDirectory}/Pictures/Wallpapers/dawn_mountain.jpg"
                ];
                wallpaper = [
                  ",${config.home.homeDirectory}/Pictures/Wallpapers/dawn_mountain.jpg"
                ];
              };
            };

            # Hyprlock (PAM is wired in system config)
            programs.hyprlock.enable = true;

            # Start a Polkit authentication agent for Hyprland sessions
            systemd.user.services.hyprpolkitagent = {
              Unit = {
                Description = "Hyprland Polkit Authentication Agent";
                After = [ "graphical-session.target" ];
                Wants = [ "graphical-session.target" ];
              };
              Service = {
                ExecStart = "${pkgs.hyprpolkitagent}/bin/hyprpolkitagent";
                Restart = "on-failure";
              };
              Install = { WantedBy = [ "graphical-session.target" ]; };
            };

            # Hyprland config (kept in HM; UWSM will pick HM vars)
            wayland.windowManager.hyprland = {
              enable = true;
              package = null;           # use system package from NixOS module
              systemd.enable = false;   # UWSM handles the session

              settings = {
                # Monitors — default to 175 Hz but with VRR OFF by default to avoid artifacts
                monitor = [
                  # Left: 3440x1440@175 at (0,0), scale 1, VRR off, 8-bit
                  "HDMI-A-1, 3440x1440@175, 0x0, 1, vrr, 0, bitdepth, 8"
                  # Right: 4K@60 to the right, VRR off, 8-bit
                  "DP-1, 3840x2160@60, 3440x0, 1, vrr, 0, bitdepth, 8"
                ];

                general = {
                  gaps_in = 6;
                  gaps_out = 8;
                  border_size = 2;
                  layout = "dwindle";
                  resize_on_border = true;
                };

                # Dwindle options for split toggling
                dwindle = { preserve_split = true; };

                decoration = {
                  rounding = 8;
                  blur = {
                    enabled = true;
                    size = 6;
                    passes = 2;
                    ignore_opacity = true;
                  };
                };

                animations = { enabled = true; };

                misc = {
                  disable_hyprland_logo = true;
                  vfr = false;  # turn off variable frame scheduling to reduce flicker
                };

                input = {
                  kb_layout = "us";
                  follow_mouse = 1;
                  accel_profile = "flat";  # disable mouse acceleration
                };

                "$mod" = "SUPER";

                bind = [
                  "$mod, RETURN, exec, kitty"
                  "$mod, Q, killactive"
                  "$mod, SPACE, exec, wofi --show drun"
                  "$mod, E, exec, thunar"
                  ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
                  "$mod, S, exec, swaync-client -t"
                  "$mod SHIFT, L, exec, hyprlock"
                  "$mod, L, exit"
                  "$mod, T, togglefloating"
                  "$mod, F, fullscreen"

                  # Toggle split orientation (requires dwindle.preserve_split = true)
                  "$mod, J, layoutmsg, togglesplit"

                  # Quick testing toggles for stability (change rates/VRR live)
                  "$mod ALT, R, exec, hyprctl keyword monitor \"HDMI-A-1, 3440x1440@165, 0x0, 1, vrr, 0, bitdepth, 8\""
                  "$mod ALT, T, exec, hyprctl keyword monitor \"HDMI-A-1, 3440x1440@175, 0x0, 1, vrr, 0, bitdepth, 8\""
                  "$mod ALT, V, exec, hyprctl keyword monitor \"HDMI-A-1, 3440x1440@175, 0x0, 1, vrr, 2, bitdepth, 8\""
                ];

                # Mouse drags (Super + Left = move, Super + Right = resize)
                bindm = [
                  "$mod, mouse:272, movewindow"
                  "$mod, mouse:273, resizewindow"
                ];

                env = [
                  "XDG_CURRENT_DESKTOP,Hyprland"
                  "DESKTOP_SESSION,Hyprland"
                  # Helps NVIDIA cursor/flicker artifacts on some setups
                  "WLR_NO_HARDWARE_CURSORS,1"
                ];
              };
            };

            # Ensure UWSM sessions import HM env
            xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

            # Fonts
            fonts.fontconfig.enable = true;
          };
        })
      ];
    };
  };
}
