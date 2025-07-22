{ inputs, ... }:
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

  mkHome :: attrset -> attrset
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
      extraSpecialArgs = moduleArgs // {
        inherit inputs;
      };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs extraSpecialArgs;
      modules = [
        # Core home configuration
        {
          home = {
            username = name;
            homeDirectory = "/home/${name}";
            inherit stateVersion;
          };
          programs.home-manager.enable = true;
        }
        # User-specific settings
        # (root + "/homes/${name}")
      ] ++ modules;
    };
}
