{
  description = "NixOS + Home Manager + Lanzaboote (Secure Boot)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    # Lanzaboote as in the quickstart
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, zen-browser, lanzaboote, ... }:
  let
    system = "x86_64-linux";
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        # Your normal system config (keep Secure Boot–agnostic settings here)
        ./configuration.nix

        # Home Manager
        home-manager.nixosModules.home-manager

        # Lanzaboote module per quickstart
        lanzaboote.nixosModules.lanzaboote

        # Inline module for HM setup + Lanzaboote toggles
        ({ pkgs, lib, ... }: {
          # System-wide nixpkgs settings
          nixpkgs.config.allowUnfree = true;

          # Secure Boot tooling handy for debugging
          environment.systemPackages = [ pkgs.sbctl ];

          # Lanzaboote replaces systemd-boot per docs
          boot.loader.systemd-boot.enable = lib.mkForce false;

          boot.lanzaboote = {
            enable = true;
            pkiBundle = "/var/lib/sbctl";
          };

          # Home Manager wiring
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.pierce = { pkgs, ... }: {
            home.stateVersion = "24.11";

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
              initExtra = ''
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

            home.packages = with pkgs; [
              ripgrep fd tree jq fzf bat eza zoxide just
              lmstudio codex
              (zen-browser.packages.${system}.zen-browser)
            ];
          };

          # System zsh as login shell
          programs.zsh.enable = true;
          users.users.pierce.shell = pkgs.zsh;
        })
      ];
    };
  };
}
