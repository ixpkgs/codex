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
          tag = "rust-v0.138.0";
          version = "rust-v0.138.0";
          commit = "c18e9f478bc940ef1ef8e1c426364c0fe3d86b73";
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
            x86_64-linux = "sha256-MDDto5nMiO2Ow8KAYWPde9xzkCkjR+UNj+BTgaguFd8=";
            aarch64-linux = "sha256-uOkG7fvBquAIucWPdmJmaiyRpYfCy8kRlqD2L8UQI1w=";
            x86_64-darwin = "sha256-OaeKHxAZgDcK/Y+D+BAmGrwY7SS0SpddGxaAK8LEsnw=";
            aarch64-darwin = "sha256-zDnBXPL4um1k5DiaYAIAxVTeqnTznrpJ5NvLL3U/SkU=";
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
