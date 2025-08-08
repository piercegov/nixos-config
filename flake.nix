{
  description = "NixOS + Home Manager with Zen Browser & Codex CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, zen-browser, ... }:
  let
    system = "x86_64-linux";

    overlays = [
      (final: prev: {
        codex-cli = final.rustPlatform.buildRustPackage rec {
          pname = "codex-cli";
          version = "0.16.0";

          src = final.fetchFromGitHub {
            owner  = "openai";
            repo   = "codex";
            rev    = "rust-v${version}";
            sha256 = "04ph8ppibd66z25lj66dhygzixxan3ah6n9d1k0hf5j6h2rzw1rf";
          };

          sourceRoot = "source/codex-rs";
          cargoHash  = "sha256-zgmiWyWB08v1WQVFzxpC/LGwF+XXbs8iW1d7i9Iw0Q4=";
          doCheck    = false;

          nativeBuildInputs = [ final.pkg-config ];
          buildInputs       = [ final.openssl ];

          meta = with final.lib; {
            description = "Command-line interface for Codex";
            homepage    = "https://github.com/openai/codex";
            license     = licenses.mit;
            mainProgram = "codex";
          };
        };
      })
    ];
  in {
    packages.${system}.codex-cli =
      (import nixpkgs { inherit system overlays; }).codex-cli;

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        { nixpkgs.overlays = overlays; }

        ./configuration.nix

        home-manager.nixosModules.home-manager

        # 👇 wrap as a function so `pkgs` is in scope
        ({ config, pkgs, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.pierce = { pkgs, ... }: {
            home.stateVersion = "24.11";

            programs.zsh = {
              enable = true;
              enableCompletion = true;
              autosuggestion.enable = true;      # singular
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

            home.packages = with pkgs; [
              ripgrep fd tree jq fzf bat eza zoxide just
              codex-cli
              (zen-browser.packages.${system}.zen-browser)
            ];
          };

          # System-level zsh (since you want it as login shell)
          programs.zsh.enable = true;
          users.users.pierce.shell = pkgs.zsh;

          # Optional: expose package completions
          # environment.pathsToLink = [ "/share/zsh" ];
        })
      ];
    };
  };
}

