{ pkgs }:

with pkgs;

{
  update-vendor-hash = callPackage ./update-vendor-hash.nix { };
}
