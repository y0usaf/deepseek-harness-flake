{
  lib,
  autoPatchelfHook,
  bashInteractive,
  buildNpmPackage,
  fetchurl,
  jq,
  makeWrapper,
  runCommand,
  stdenv,
  stdenvNoCC,
  xz,
}:

let
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version;

  node = stdenvNoCC.mkDerivation {
    pname = "node-dsh";
    version = "24.10.0";
    src = fetchurl {
      url = "https://nodejs.org/dist/v24.10.0/node-v24.10.0-linux-x64.tar.xz";
      hash = "sha256-JkL0QohprKMkQ2YP1xs5GOK+Eneomb3K62TJO1S1rxc=";
    };
    nativeBuildInputs = [ autoPatchelfHook xz ];
    buildInputs = [ stdenv.cc.cc.lib ];
    installPhase = ''
      mkdir -p $out
      cp -r . $out/
      autoPatchelf $out/bin/node
    '';
    meta.platforms = [ "x86_64-linux" ];
  };

  srcWithLock = runCommand "dsh-source" { nativeBuildInputs = [ jq xz ]; } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    jq 'del(.devDependencies)' $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "dsh";
  inherit version;
  src = srcWithLock;

  npmDepsFetcherVersion = 2;
  npmDepsHash = versionData.npmDepsHash;

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    # /bin/bash does not exist on NixOS (llm-agents.nix issue #8086).
    substituteInPlace \
      $out/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-terminal-bash/lib/index.js \
      --replace-fail '"/bin/bash"' '"${lib.getExe bashInteractive}"'

    # Replace the upstream bin (a bare `lib/bin.js` symlink) with a
    # wrapper that runs node with --expose-internals, which dsh requires.
    rm $out/bin/dsh
    makeWrapper ${node}/bin/node $out/bin/dsh \
      --argv0 dsh \
      --add-flags "--expose-internals" \
      --add-flags "$out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
  '';

  meta = {
    description = "DeepSeek Harness (dsh) CLI: profile boot, plugin management, and browser UI";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    changelog = "https://github.com/deepseek-ai/deepseek-harness/releases";
    downloadPage = "https://www.npmjs.com/package/@deepseek-ai/dsh";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = [ "x86_64-linux" ];
  };
}
