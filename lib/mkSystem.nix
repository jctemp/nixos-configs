{ inputs, lib }:
/**
  Description

  # Arguments

  - `config` (attrset): User home definition
    - name (string): Username for the configuration
    - system (string): The target systems this profile supports
    - stateVersion (string): Version of homeManager the user profile was initially created
    - modules (list): Custom modules provided by the caller
    - moduleArgs (attrset): Args that should be passed to the modules

  # Type

  mkSystem :: attrset -> attrset
*/
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
