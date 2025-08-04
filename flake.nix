{
  description = "NixOS config with Zen browser";

  inputs = {
    nixpkgs.url        = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser.url    = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, zen-browser, ... }:          # ① zen-browser in scope
  let
    system = "x86_64-linux";                              # adjust if aarch64
    pkgs   = import nixpkgs { inherit system; };
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {# ② replace with `hostname`
      inherit system;

      modules = [
        ./configuration.nix                               # your existing config

        ({ ... }: {                                       # ③ extra module
          environment.systemPackages = [
            # choose one: `specific` (newer CPUs) or `generic`
            zen-browser.packages.${system}.zen-browser
          ];
        })
      ];
    };
  };
}

