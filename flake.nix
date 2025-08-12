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

        # Wire Hyprland packages from upstream flake
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
              shellAliases = {
                ll = "eza -lah";
                gs = "git status -sb";
                v  = "nvim";
              };
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
              wl-clipboard grim slurp wofi swaynotificationcenter waybar
              hyprpaper hypridle hyprlock hyprpicker hyprsysteminfo
              networkmanagerapplet pavucontrol playerctl
              (zen-browser.packages.${system}.zen-browser)
              # themes/fonts
              papirus-icon-theme catppuccin-gtk
              nerd-fonts.fira-code nerd-fonts.jetbrains-mono
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

            # Waybar via HM (simple config)
            programs.waybar = {
              enable = true;
              settings = {
                mainBar = {
                  layer = "top";
                  position = "top";
                  modules-left = [ "hyprland/workspaces" "hyprland/window" ];
                  modules-right = [ "pulseaudio" "network" "battery" "clock" "tray" ];
                  "hyprland/workspaces" = { format = "{icon}"; };
                  pulseaudio = { tooltip = false; };
                  network = { format = "{ifname} {ipaddr}"; format-disconnected = "down"; };
                  battery = { format = "{capacity}%"; };
                  clock = { format = "{:%a %b %d  %H:%M}"; };
                  tray = { spacing = 8; };
                };
              };
              style = ''
                * { font-family: "JetBrainsMono Nerd Font", "FiraCode Nerd Font", sans-serif; }
                window#waybar { background: rgba(24,24,37,0.7); color: #cdd6f4; }
                #workspaces button.active { background: #89b4fa; color: #1e1e2e; }
              '';
            };

            # Hyprland config (kept in HM, UWSM will pick HM vars)
            wayland.windowManager.hyprland = {
              enable = true;
              package = null;           # use system package from NixOS module
              systemd.enable = false;   # UWSM handles the session
              extraConfig = ''
                # Basic look
                general {
                  gaps_in = 6
                  gaps_out = 8
                  border_size = 2
                  layout = dwindle
                }
                decoration {
                  rounding = 8
                  blur { enabled = true; size = 6; passes = 2; ignore_opacity = true; }
                }
                animations {
                  enabled = true
                  bezier ease, 0.05, 0.9, 0.1, 1.0
                  animation windows, 1, 7, ease, slide
                  animation border, 1, 10, ease
                  animation fade, 1, 7, ease
                }
                misc {
                  disable_hyprland_logo = true
                  vfr = true
                }
                input {
                  kb_layout = us
                  follow_mouse = 1
                  touchpad { natural_scroll = true }
                }

                $mod = SUPER
                bind = $mod, RETURN, exec, kitty
                bind = $mod, Q, killactive
                bind = $mod, SPACE, exec, wofi --show drun
                bind = $mod, E, exec, thunar
                bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
                bind = $mod, S, exec, swaync-client -t
                bind = $mod SHIFT, L, exec, hyprlock
                bind = $mod, L, exit


                # autostart (UWSM session)
                exec-once = waybar
                exec-once = swaync
                exec-once = nm-applet
                exec-once = hyprpaper
                # set wallpaper for all monitors (adjust the path)
                exec-once = hyprctl hyprpaper reload ,"$HOME/Pictures/wallpapers/forest.jpg"
              '';
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

