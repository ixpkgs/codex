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
          tag = "rust-v0.3.0";
          version = "rust-v0.3.0";
          commit = "de04ab108de52f630ed78e5709fc166d0cb09752";
          src = builtins.fetchGit {
            url = "https://github.com/openai/codex";
            rev = commit;
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

            sourceRoot = "source/codex-rs";
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
              CARGO_PROFILE_RELEASE_LTO = "false";
              CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
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
