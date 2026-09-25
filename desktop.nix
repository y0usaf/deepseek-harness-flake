{
  lib,
  stdenv,
  fetchurl,
  _7zz,
  asar,
  jq,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  wrapGAppsHook3,
  gtk3,
  gsettings-desktop-schemas,
  bashInteractive,
  electron_44-bin,
  nodejs_24,
  python312,
  python3,
  pkg-config,
  vips,
}:

let
  version = "0.1.7-rc.1.20260924.1";

  # node-addon-require-builtin fingerprints the exact Electron runtime and
  # accepts 44.0.0 (what the DMG ships), not nixpkgs' 44.x.
  electron = electron_44-bin.overrideAttrs (old: {
    version = "44.0.0";
    src = fetchurl {
      url = "https://github.com/electron/electron/releases/download/v44.0.0/electron-v44.0.0-linux-x64.zip";
      hash = "sha256-1lKG2BJxnytMGhuAaoDyiKEFjInHsFja4eA6sl5JlEY=";
    };
    # 44.0.0 ships no separate libEGL/libGLESv2 for nixpkgs to patch.
    postFixup =
      let
        angle = "$out/libexec/electron/lib*GL*";
      in
      assert lib.hasInfix angle old.postFixup;
      lib.replaceStrings [ angle ] [ "$out/libexec/electron/libvk_swiftshader.so" ] old.postFixup;
  });

  # The app bundles darwin-arm64 builds of these native packages. Swap in the
  # Linux x64 build of the same version: bundled dir -> npm replacement.
  natives = {
    "sherpa-onnx-darwin-arm64" = {
      pkg = "sherpa-onnx-linux-x64";
      version = "1.13.8";
      hash = "sha256-EykbzYJdpYWMono1RD6aLCKaQGFsCRAIbeLbEsXJMSw=";
    };
    "node-addon-require-builtin-darwin-arm64" = {
      pkg = "node-addon-require-builtin-linux-x64-gnu";
      version = "0.1.6";
      hash = "sha256-selLqAVsp0i/yRv+46g3qR/vYN0PE8fKJSggkLc+NLM=";
    };
    "@vscode/ripgrep-darwin-arm64" = {
      pkg = "@vscode/ripgrep-linux-x64";
      version = "1.18.0";
      hash = "sha256-jMBuJeKfnCWO6aCe7NdwfB6i6Z2edhUeU9vjn41rSgk=";
    };
    "@koromix/koffi-darwin-arm64" = {
      pkg = "@koromix/koffi-linux-x64";
      version = "3.3.1";
      hash = "sha256-Tl/hRecxQzG59zSIFArPqatpnD20A3UxvvPz4EKKzy4=";
    };
    # sharp's Linux prebuilds bundle a static GLib that clashes with the one
    # Electron loads (segfault in g_object_unref); sharp is built from source
    # against nixpkgs vips instead, so these are dropped without replacement.
    "@img/sharp-libvips-darwin-arm64" = null;
    "@img/sharp-darwin-arm64" = null;
    "@deepseek-ai/node-addon-system-darwin-arm64" = {
      pkg = "@deepseek-ai/node-addon-system-linux-x64";
      version = "0.1.2";
      hash = "sha256-d/t3G+4hM8P/0flse5Q13bHMrucraBT29DkTQ6YRzCA=";
    };
    # No Linux native build exists; the package falls back to wasm.
    "@deepseek-ai/libreoffice-kit-darwin-arm64" = {
      pkg = "@deepseek-ai/libreoffice-kit-wasm";
      version = "0.1.0";
      hash = "sha256-LzEc21gm5Cgt5ueZOL9+B96Aqs+335x+TC9MfeeskVc=";
    };
    # The bundled copy only carries darwin prebuilds; the npm tarball has linux-x64.
    "node-pty" = {
      pkg = "node-pty";
      version = "1.2.0-beta.15";
      hash = "sha256-EUrIDD/gde/3YhekEi0TVXZYJpX0nAOl2jg1zfwvicU=";
    };
  };

  swapNatives = lib.concatStrings (
    lib.mapAttrsToList (
      old: n:
      ''
        rm -rf "$modules/${old}"
      ''
      + lib.optionalString (n != null) ''
        mkdir -p "$modules/${n.pkg}"
      tar -xzf ${
        fetchurl {
          url = "https://registry.npmjs.org/${n.pkg}/-/${baseNameOf n.pkg}-${n.version}.tgz";
          inherit (n) hash;
        }
      } --strip-components=1 -C "$modules/${n.pkg}"
      ''
    ) natives
  );

  # runtime.json distribution name -> nixpkgs python attribute.
  pythonDists = {
    numpy = "numpy";
    pandas = "pandas";
    python-dateutil = "python-dateutil";
    six = "six";
    tzdata = "tzdata";
    python-docx = "python-docx";
    python-pptx = "python-pptx";
    openpyxl = "openpyxl";
    Pillow = "pillow";
    lxml = "lxml";
    XlsxWriter = "xlsxwriter";
    typing_extensions = "typing-extensions";
    et_xmlfile = "et-xmlfile";
  };
  python = python312.withPackages (ps: map (a: ps.${a}) (lib.attrValues pythonDists));

  # Fields of the bundled primary-runtime/runtime.json that describe the payload
  # we substitute; desktopVersion and pnpm are kept from upstream.
  runtimeOverrides = builtins.toJSON {
    platform = "linux";
    arch = "x64";
    python = python312.version;
    node = nodejs_24.version;
    pythonPackages = lib.mapAttrs (_: a: python312.pkgs.${a}.version) pythonDists;
  };
in
stdenv.mkDerivation {
  pname = "dsh-desktop";
  inherit version;

  # Upstream removed this DMG from download.deepseek.com; mirrored unmodified.
  src = fetchurl {
    url = "https://github.com/y0usaf/deepseek-harness-flake/releases/download/desktop-${version}/deepseek-harness-${version}-mac-arm64.dmg";
    hash = "sha256-+9+LbmdgzPj1F0iqOhLDA5fwJfEKgrQsWcrceAbCSZQ=";
  };

  nativeBuildInputs = [
    _7zz
    asar
    jq
    autoPatchelfHook
    copyDesktopItems
    wrapGAppsHook3
    nodejs_24
    python3
    pkg-config
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    gtk3
    gsettings-desktop-schemas
    vips
  ];

  unpackPhase = ''
    runHook preUnpack
    # Exit 2 is 7zz warning about symlinks and resource forks.
    7zz x -y "$src" -odmg >/dev/null || [ $? -eq 2 ]
    mv dmg/*/*.app/Contents/Resources resources
    rm -rf dmg
    runHook postUnpack
  '';

  buildPhase = ''
    runHook preBuild

    # A plain resources/app directory needs no repacking; Electron loads it directly.
    asar extract resources/app.asar app
    modules=app/dsh/node_modules
    ${swapNatives}
    # Loaded from src/build/Release before any @img prebuild.
    pushd $modules/sharp/src
    SHARP_FORCE_GLOBAL_LIBVIPS=1 node ${nodejs_24}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js \
      rebuild --release --nodedir=${nodejs_24}
    mv build/Release/sharp-*.node .
    rm -rf build && mkdir -p build/Release && mv sharp-*.node build/Release/
    popd

    # /bin/bash does not exist on NixOS.
    substituteInPlace $modules/@deepseek-ai/dsh-terminal-bash/lib/index.js \
      --replace-fail '"/bin/bash"' '"${lib.getExe bashInteractive}"'
    # The mandatory-update policy throws on Linux; without the key it is never constructed.
    jq 'del(.dshMandatoryUpdatePolicy) + {productName: "DeepSeek Harness", desktopName: "deepseek-harness.desktop"}' \
      app/package.json > package.json && mv package.json app/package.json

    # Replace the macOS Python/Node payload with Nix-built equivalents.
    payload=resources/runtime/primary-runtime
    jq --argjson o '${runtimeOverrides}' 'del(.payloadDigest) + $o' $payload/runtime.json > runtime.json
    mv runtime.json $payload/runtime.json
    rm -rf $payload/dependencies/{python,node}
    ln -s ${python} $payload/dependencies/python
    mkdir -p $payload/dependencies/node/{bin,node_modules}
    ln -s ${lib.getExe nodejs_24} $payload/dependencies/node/bin/node

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Electron resolves resources/ next to its own binary and reports
    # app.isPackaged only when that binary is not named "electron".
    dest=$out/lib/deepseek-harness
    mkdir -p $out/lib
    cp -r ${electron}/libexec/electron $dest
    chmod -R u+w $dest
    mv $dest/electron $dest/deepseek-harness
    rm -f $dest/resources/default_app.asar
    # No app-update.yml: electron-updater stays disabled.
    cp -r app $dest/resources/app
    cp -r resources/runtime resources/icon.png $dest/resources/

    install -Dm644 resources/icon.png $out/share/icons/hicolor/1024x1024/apps/deepseek-harness.png

    runHook postInstall
  '';

  # Only the swapped npm prebuilds need patching; the Electron copy already is.
  dontAutoPatchelf = true;
  dontPatchELF = true;
  # musl variants ship alongside glibc ones and are never loaded here.
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];
  dontWrapGApps = true;
  postFixup = ''
    autoPatchelf $out/lib/deepseek-harness/resources/app
    makeWrapper $out/lib/deepseek-harness/deepseek-harness $out/bin/deepseek-harness \
      "''${gappsWrapperArgs[@]}"
  '';
  dontStrip = true;

  desktopItems = [
    (makeDesktopItem {
      name = "deepseek-harness";
      desktopName = "DeepSeek Harness";
      exec = "deepseek-harness %U";
      icon = "deepseek-harness";
      startupWMClass = "DeepSeek Harness";
      mimeTypes = [ "x-scheme-handler/dsh" ];
      categories = [ "Development" ];
    })
  ];

  meta = {
    description = "DeepSeek Harness desktop app, repackaged from the macOS DMG for Linux";
    homepage = "https://harness.deepseek.com";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "deepseek-harness";
    platforms = [ "x86_64-linux" ];
  };
}
