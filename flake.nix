{
  description = "A macOS menu bar app that cuts in on every screen before your next Google Calendar meeting";

  inputs = {
    # A GitHub input, as Dependabot updates only GitHub, GitLab, Sourcehut
    # and git inputs, not the channel tarball.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      # Calendrop is an AppKit app, so only macOS builds it.
      systems = [ "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        # mkShellNoCC keeps Nix's compiler wrappers, SDK and DEVELOPER_DIR out of
        # the environment: AppKit and SwiftUI build only with Apple's Swift
        # toolchain from Xcode or the Command Line Tools, which stays on PATH.
        default = pkgs.mkShellNoCC {
          packages = [
            pkgs.just
            pkgs.librsvg
            pkgs.nixfmt
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
