{
  description = "Configuration";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

    impermanence.url = "github:nix-community/impermanence";
    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-stable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";
    blender-bin.url = "github:edolstra/nix-warez?dir=blender";
    blender-bin.inputs.nixpkgs.follows = "nixpkgs-stable";
  };

  outputs =
    { self, flake-parts, ... }@inputs:
    let
      nclib = import "${self}/lib" {
        inherit inputs;
        inherit (inputs.nixpkgs-stable) lib;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        _module.args = { inherit nclib; };

        imports = [
          # Hosts and their configurations
          ./hosts
          # Available users and their configurations
          ./homes
        ];

        flake = {
          nixosModules = {
            nixos = ./modules/nixos;
            core = ./modules/nixos/core;
            hardware = ./modules/nixos/hardware;
            services = ./modules/nixos/services;
            storage = ./modules/nixos/storage;
            profiles = ./modules/nixos/profiles;
          };
          homeModules = {
            home = ./modules/home;
            core = ./modules/home/core;
            applications = ./modules/home/applications;
            desktop = ./modules/home/desktop;
            profiles = ./modules/home/profiles;
          };
        };

        systems = [ "x86_64-linux" ];

        perSystem =
          { system, ... }:
          {
            # nixpkgs is not part of inputs - enhance manually adding pkgs
            _module.args.pkgs = import inputs.nixpkgs-unstable { inherit system; };
          };
      }
    );
}
