{
  description = "DeepSeek Harness (dsh) packaged from the published npm tarball";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkDsh =
        system:
        nixpkgs.legacyPackages.${system}.callPackage ./dsh.nix { };
    in
    {
      packages = forAllSystems (system: {
        dsh = mkDsh system;
        default = mkDsh system;
      });

      overlays.default = final: prev: {
        dsh = final.callPackage ./dsh.nix { };
      };
    };
}
