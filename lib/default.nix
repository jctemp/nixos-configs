{ inputs, lib }:
{
  mkSystem = import ./mkSystem.nix { inherit inputs lib; };
  mkHome = import ./mkHome.nix { inherit inputs lib; };
  utils = import ./utils.nix { inherit inputs lib; };
}
