{
  description = "Versioned Nix package for the OpenAI Codex CLI";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
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
          pkgs = nixpkgs.legacyPackages.${system};
          lib = pkgs.lib;
          tag = "rust-v0.144.2";
          version = "rust-v0.144.2";
          commit = "a6645b6b8a656360fa16fb7e1c6721d0697d3d6a";
          upstreamVersion = lib.removePrefix "rust-v" version;
          useGnuLinux =
            lib.versionAtLeast upstreamVersion "0.54.0"
            && lib.versionOlder upstreamVersion "0.128.0";
          targets = {
            x86_64-linux = "x86_64-unknown-linux-${if useGnuLinux then "gnu" else "musl"}";
            aarch64-linux = "aarch64-unknown-linux-${if useGnuLinux then "gnu" else "musl"}";
            x86_64-darwin = "x86_64-apple-darwin";
            aarch64-darwin = "aarch64-apple-darwin";
          };
          assetHashes = {
            x86_64-linux = "sha256-JXz5/mWgesN/joQvL6VChB9ZoM9peEPLRWrdt2zhJIE=";
            aarch64-linux = "sha256-x/dhalnfKxv2D3l2iXMoXRfOxXPr81yNVG1bcoX+mR8=";
            x86_64-darwin = "sha256-I3z6v6SuQTOlVWlp3Lo3YI7T9KvhznaqH5rGHI2vTOc=";
            aarch64-darwin = "sha256-NGN0msHDdvexCyQFlc2b4teclTOVz2j/Sx2bpCH9gUg=";
          };
          target = targets.${system};
          isBundle = lib.versionAtLeast upstreamVersion "0.140.0";
          assetName =
            if isBundle then "codex-package-${target}.tar.gz" else "codex-${target}.tar.gz";
          releaseArchive = pkgs.fetchurl {
            url = "https://github.com/openai/codex/releases/download/${tag}/${assetName}";
            hash = assetHashes.${system};
          };
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "codex";
            inherit version;
            inherit releaseArchive;

            passthru.upstreamCommit = commit;

            dontUnpack = true;
            nativeBuildInputs = [ pkgs.makeWrapper ]
              ++ lib.optionals (pkgs.stdenv.hostPlatform.isLinux && useGnuLinux) [
                pkgs.autoPatchelfHook
            ];
            buildInputs = lib.optionals (pkgs.stdenv.hostPlatform.isLinux && useGnuLinux) [
              pkgs.libcap
              pkgs.openssl
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
            ];

            installPhase = ''
              runHook preInstall

              release_dir="$TMPDIR/codex-release"
              mkdir -p "$release_dir" "$out/bin" "$out/libexec/codex"
              tar -xzf "$releaseArchive" -C "$release_dir"

              if [ -x "$release_dir/bin/codex" ]; then
                cp -R "$release_dir"/. "$out/libexec/codex/"
                real_codex="$out/libexec/codex/bin/codex"
                bundled_path="$out/libexec/codex/codex-path"
              else
                install -Dm755 "$release_dir/codex-${target}" "$out/libexec/codex/codex"
                real_codex="$out/libexec/codex/codex"
                bundled_path=""
              fi

              makeWrapper "$real_codex" "$out/bin/codex" \
                --prefix PATH : "$bundled_path:${
                  lib.makeBinPath (
                    [ pkgs.ripgrep ]
                    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.bubblewrap ]
                  )
                }"

              runHook postInstall
            '';

            doInstallCheck = true;
            installCheckPhase = ''
              "$out/bin/codex" --version | grep -F "${upstreamVersion}"
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
