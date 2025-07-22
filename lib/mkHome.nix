{ inputs, ... }:
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
