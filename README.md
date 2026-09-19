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

## Pinned version

`0.1.5-rc.2` -- the current npm `latest` / `next` dist-tag. Hashes live in
`hashes.json`; the `package-lock.json` is generated from the tarball's own
manifest with `devDependencies` removed (they reference an unpublished
`@deepseek-ai` package and break `npm install`).

## Caveat

Upstream is a **developer preview** and is moving fast; expect breaking changes
between releases, including in the CLI surface and profile layout.
