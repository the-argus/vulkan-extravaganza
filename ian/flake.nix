{
  description = "Vulkan tutorial environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    kdab-flake.url = "github:the-argus/kdab-flake";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    kdab-flake,
    ...
  }: let
    supportedSystems = let
      inherit (flake-utils.lib) system;
    in [
      system.aarch64-linux
      system.x86_64-linux
    ];
  in
    flake-utils.lib.eachSystem supportedSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      devShell = pkgs.mkShell {
        packages = with pkgs; [
          # tools
          valgrind
          gdb
          zig_0_11
          pkg-config # needed for system libs

          # system libs for building windowed application
          wayland
          wayland-protocols
          wayland-scanner
          libxkbcommon
          xorg.libxcb

          # vulkan
          vulkan-validation-layers
          kdab-flake.packages.${system}.software.vulkan-sdk
        ];
      };
    });
}
