{
  description = "CorrectRoadH CLI releases for Nix";

  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in rec {
          concord = pkgs.callPackage ./nix/concord.nix { };
          default = concord;
        });
      apps = forAllSystems (system: rec {
        concord = {
          type = "app";
          program = "${self.packages.${system}.concord}/bin/concord";
          meta.description = "Concord SDLC CLI";
        };
        default = concord;
      });
      checks = forAllSystems (system: {
        concord = self.packages.${system}.concord.passthru.tests.lifecycle;
      });
    };
}
