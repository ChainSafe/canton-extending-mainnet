{
  # NixOS deployment for the Extending Mainnet control center - SKELETON (RFC-001).
  # Full-build plan: ../history/rfcs/RFC-001-nixos-deployment.md
  description = "Extending Mainnet deployment (skeleton)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # TODO(RFC-001): real hosts are x86_64-linux / aarch64-linux NixOS configs.
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      # TODO(RFC-001): nixosConfigurations.localnet, .dedicated-sync-operator, .sv, .validator
      packages.${system}.placeholder =
        pkgs.writeShellScriptBin "placeholder" ''
          echo "RFC-001: NixOS deployment not yet implemented."
          echo "See history/rfcs/RFC-001-nixos-deployment.md"
        '';
    };
}
