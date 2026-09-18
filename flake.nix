{
  description = "Versioned Nix package for the OpenAI Codex CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, rust-overlay, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };
          lib = pkgs.lib;
          tag = "rust-v0.2.0";
          version = "rust-v0.2.0";
          commit = "b3bffa594d67dce8fd916dc74b8daea7a2c6f9f3";
          src = pkgs.fetchFromGitHub {
            owner = "openai";
            repo = "codex";
            rev = commit;
            hash = "sha256-lpZsECLWmoGJYafL3FlmR6WwOcynGgqWq6IUB+/y6lY=";
          };
          rust = pkgs.rust-bin.stable.latest.minimal;
          rustPlatform = pkgs.makeRustPlatform {
            cargo = rust;
            rustc = rust;
          };
        in
        {
          default = rustPlatform.buildRustPackage {
            pname = "codex";
            inherit version src;

            sourceRoot = "${src.name}/codex-rs";
            cargoHash = "sha256-DIDAk5ibwEQ9mwOUS2JNFEA2npVK9TBph/TuwiJgfL4=";
            cargoBuildFlags = [
              "--package"
              "codex-cli"
            ];
            doCheck = false;

            nativeBuildInputs = with pkgs; [
              clang
              cmake
              makeWrapper
              pkg-config
            ];
            buildInputs = with pkgs; [
              libclang
              openssl
            ] ++ lib.optionals stdenv.hostPlatform.isLinux [ libcap ];

            env = {
              LIBCLANG_PATH = "${lib.getLib pkgs.libclang}/lib";
              NIX_CFLAGS_COMPILE = lib.optionalString pkgs.stdenv.cc.isGNU (
                "-std=gnu17 -Wno-error=incompatible-pointer-types -Wno-error=implicit-function-declaration"
              );
            };

            postFixup = ''
              wrapProgram "$out/bin/codex" --prefix PATH : ${
                lib.makeBinPath (
                  [ pkgs.ripgrep ]
                  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.bubblewrap ]
                )
              }
            '';

            meta = {
              description = "Lightweight coding agent that runs in your terminal";
              homepage = "https://github.com/openai/codex";
              changelog = "https://github.com/openai/codex/releases/tag/${tag}";
              license = lib.licenses.asl20;
              mainProgram = "codex";
              platforms = lib.platforms.unix;
            };
          };
        }
      );
    };
}
