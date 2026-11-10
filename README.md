# deepseek-harness-flake

A self-contained Nix flake packaging **DeepSeek Harness** (`dsh`), the
open-source agent harness from DeepSeek AI. Upstream ships **no flake**; this
packages the published npm tarball
[`@deepseek-ai/dsh`](https://www.npmjs.com/package/@deepseek-ai/dsh) into a
runnable `dsh` binary.

## Use as a flake input

```nix
{
  inputs.deepseek-harness-flake.url = "github:y0usaf/deepseek-harness-flake";
}
```

Then use `inputs.deepseek-harness-flake.packages.${system}.dsh`, or apply the
overlay to get `pkgs.dsh`:

```nix
{
  nixpkgs.overlays = [ inputs.deepseek-harness-flake.overlays.default ];
  # environment.systemPackages = [ pkgs.dsh ];
}
```

## Build and run

```sh
nix build .#dsh          # or: nix build
./result/bin/dsh --version
```

Run the browser UI (writes a composed profile under `$DSH_HOME`):

```sh
DSH_HOME=$(mktemp -d) ./result/bin/dsh web --port 3101 --no-open
```

`dsh web` prints a URL with an auth token; requests without it get HTTP 401 by
design.

## Desktop app

`packages.x86_64-linux.dsh-desktop` repackages DeepSeek's official macOS
desktop build (Electron) for Linux, like codex-desktop-flake does for Codex:

```sh
nix run .#dsh-desktop
```

The arm64 DMG is pulled from this repo's
[`desktop-0.1.7-rc.1.20260924.1` release](https://github.com/y0usaf/deepseek-harness-flake/releases/tag/desktop-0.1.7-rc.1.20260924.1),
an unmodified mirror: DeepSeek removed it from `download.deepseek.com`. The
app and its bundled packages are MIT licensed. The build:

- runs the app on Electron **44.0.0** exactly (nixpkgs' binary, version
  overridden): `node-addon-require-builtin` fingerprints the runtime and
  rejects other 44.x releases;
- swaps each darwin-arm64 native package for its linux-x64 npm build of the
  same version (table in `desktop.nix`); `libreoffice-kit` uses its wasm
  build;
- builds `sharp` from source against nixpkgs `vips`. Its Linux prebuilds
  bundle a static GLib that segfaults inside Electron;
- replaces the bundled macOS Python/Node payload with nixpkgs
  `python312.withPackages` and `nodejs_24`;
- drops the mandatory-update policy (it throws on Linux) and
  `app-update.yml` (auto-update stays off).

User data lives in `~/.dsh` and `~/.config/DeepSeek Harness`.

## Pinned version

CLI: `0.2.1-rc.3`. Hashes live in `hashes.json`; the `package-lock.json` is
generated from the tarball's own manifest with `devDependencies` removed (they
reference an unpublished `@deepseek-ai` package and break `npm install`).

dsh intercepts Node internals through a native loader that only recognizes the
V8 layout of Node **24.10.0**, so the package runs on that release's official
Linux x64 binary rather than nixpkgs' newer Node.

## Caveat

Upstream is a **developer preview** and is moving fast; expect breaking changes
between releases, including in the CLI surface and profile layout.
