{ inputs, lib }:
{
  name,
  system,
  stateVersion,
  modules ? [ ],
  moduleArgs ? { },
}:
{
  inherit name;
  value =
    let
      pkgs = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
        overlays = [ inputs.blender-bin.overlays.default ];
      };
      specialArgs = moduleArgs // {
        inherit inputs;
        inherit (inputs) self;
      };
    in
    lib.homeManagerConfiguration {
      inherit pkgs specialArgs;
      modules = [
        # Core system configurations
        {
          system.stateVersion = stateVersion;
          networking.hostName = name;
          networking.hostId = builtins.substring 0 8 (builtins.hashString "md5" name);
        }
        # User-specific settings
        # (root + "/hosts/${name}")

        # Third party modules
        inputs.disko.nixosModules.disko
        inputs.nixos-facter-modules.nixosModules.facter
        inputs.impermanence.nixosModules.impermanence
      ] ++ modules;
    };
}
