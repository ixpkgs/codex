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
          tag = "rust-v0.14.0";
          version = "rust-v0.14.0";
          commit = "fd92ea1e96b0695c88302331d7830f84453a6f74";
          targets = {
            x86_64-linux = "x86_64-unknown-linux-musl";
            aarch64-linux = "aarch64-unknown-linux-musl";
            x86_64-darwin = "x86_64-apple-darwin";
            aarch64-darwin = "aarch64-apple-darwin";
          };
          assetHashes = {
            x86_64-linux = "sha256-bcuBoy4PciDw3aV2TxRXDR/bjU801Y08i6MM7Yv83mU=";
            aarch64-linux = "sha256-qI9642uwmt+xV+sOE+1q8Dy7NSqrLaluidR+MsMM6R4=";
            x86_64-darwin = "sha256-yCtbqEb5ZhMLFVQtVmR0HTUeJPy4qjbHkvwXf/b99uQ=";
            aarch64-darwin = "sha256-GHIZMJNFpiilJcaxX3BhJZayC5YGr25BbXhI6KJxgWc=";
          };
          target = targets.${system};
          upstreamVersion = lib.removePrefix "rust-v" version;
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
            nativeBuildInputs = [ pkgs.makeWrapper ];

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
