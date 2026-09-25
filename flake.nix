{
  description = "DeepSeek Harness (dsh): CLI from npm, desktop app repackaged from the macOS DMG";

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
        dsh-desktop = nixpkgs.legacyPackages.${system}.callPackage ./desktop.nix { };
      });

      overlays.default = final: prev: {
        dsh = final.callPackage ./dsh.nix { };
        dsh-desktop = final.callPackage ./desktop.nix { };
      };
    };
}
