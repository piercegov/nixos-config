{
  description = "NixOS config with Zen Browser + Codex CLI (0.16.0)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, zen-browser, ... }:
  let
    system = "x86_64-linux";
    pkgs   = import nixpkgs { inherit system; };

    codex-cli = pkgs.rustPlatform.buildRustPackage rec {
      pname = "codex-cli";
      version = "0.16.0";

      src = pkgs.fetchFromGitHub {
        owner = "openai";
        repo  = "codex";
        rev   = "rust-v${version}";
        # keep your working source hash here (SRI or legacy base32 both fine)
        sha256 = "04ph8ppibd66z25lj66dhygzixxan3ah6n9d1k0hf5j6h2rzw1rf";
      };

      # The crate isn't at repo root:
      # cargoRoot  = "codex-rs";
      sourceRoot = "source/codex-rs";

      # Fill this with the *got* value from the last mismatch you saw:
      cargoHash = "sha256-zgmiWyWB08v1WQVFzxpC/LGwF+XXbs8iW1d7i9Iw0Q4=";

      nativeBuildInputs = [ pkgs.pkg-config ];
      buildInputs = [ pkgs.openssl ];
      
      doCheck = false;

      meta = with pkgs.lib; {
        description = "Command-line interface for Codex";
        homepage = "https://github.com/openai/codex";
        license = licenses.mit;
      };
    };
  in {
    packages.${system}.codex-cli = codex-cli;

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./configuration.nix
        ({ ... }: {
          environment.systemPackages = [
            zen-browser.packages.${system}.zen-browser
            codex-cli
          ];
        })
      ];
    };
  };
}

