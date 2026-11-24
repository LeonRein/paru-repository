# paru-repository

A personal [paru](https://github.com/Morganamilo/paru) **PKGBUILD repository** —
a git repo full of PKGBUILDs that paru treats just like the AUR, so packages
here can be installed and upgraded with the same commands.

| Package | Description |
| --- | --- |
| [`transparent-xcursor-theme`](transparent-xcursor-theme) | Fully transparent Xcursor theme, for hiding the pointer in cage/kiosk sessions |
| [`auto-loudness`](auto-loudness) | ISO 226:2023 loudness compensation that follows the Focusrite Scarlett volume knob |
| [`colibri-cuda-bin`](colibri-cuda-bin) | [Colibri](https://github.com/JustVugg/colibri) MoE inference engine with CUDA and Vulkan, built for RTX 50 + Zen 5 |

Nothing here is compiled on your machine. Each package installs a prebuilt
release asset, so no build tooling is pulled in — installing
`transparent-xcursor-theme` does **not** require `xcursorgen` or ImageMagick.
Those run once in the theme repository's own CI.

## Adding the repository

Requires **paru 2.0 or newer**. Add to `/etc/paru.conf` (or
`~/.config/paru/paru.conf`):

```ini
[leonrein]
Url = https://github.com/LeonRein/paru-repository.git
```

Then sync and install:

```sh
paru -Sy --pkgbuilds
paru -S transparent-xcursor-theme
```

`paru -Syu --pkgbuilds` picks up updates from then on.

### Options worth knowing

```ini
[leonrein]
Url = https://github.com/LeonRein/paru-repository.git
SkipReview = true      # skip the diff review prompt for your own PKGBUILDs
Depth = 3              # how deep to scan for PKGBUILDs; 3 is the default
```

- `Path = /home/leon/paru-repository` points at a local clone instead of a URL,
  which is handy while editing a PKGBUILD.
- PKGBUILD repos take **priority over the AUR**, so a package here masks an AUR
  package of the same name. Useful deliberately, surprising by accident.

## Installing without paru

Every package directory is a normal PKGBUILD, so `makepkg` works directly:

```sh
git clone https://github.com/LeonRein/paru-repository.git
cd paru-repository/transparent-xcursor-theme
makepkg -si
```

## Adding a package

1. Create `<name>/PKGBUILD`. Keep one directory per package at the repository
   root — paru scans recursively, three levels deep by default.
2. Generate its metadata: `cd <name> && makepkg --printsrcinfo > .SRCINFO`.
   paru reads `.SRCINFO` to resolve names and versions, so regenerate it every
   time the `PKGBUILD` changes or paru will act on stale metadata.
3. Commit and push, then `paru -Sy --pkgbuilds` on any machine using the repo.

Prefer a prebuilt release asset with a real `sha256sums` entry, so installing
stays a download-and-copy rather than a build. Where something genuinely has to
be built from source, pin the source by commit (`#commit=<sha>`) rather than by
branch or tag — a commit cannot be moved afterwards.

## Updating a package

`colibri-cuda-bin` updates itself; see below. For the others:

Bump `pkgver`, update `sha256sums` to the new release's checksum, reset
`pkgrel=1`, regenerate `.SRCINFO`, and push. Changing only the packaging and not
the upstream version means keeping `pkgver` and incrementing `pkgrel` instead.

For `transparent-xcursor-theme` the checksum comes straight from its release
workflow: the run summary prints the exact `pkgver` and `sha256sums` lines to
paste in. `updpkgsums` (from `pacman-contrib`) recomputes them locally.

## colibri-cuda-bin: built here, updated by a bot

Upstream colibri ships CUDA builds for Windows only, so this repository
builds the Linux one itself. [`.github/workflows/colibri-cuda-bin.yml`](.github/workflows/colibri-cuda-bin.yml)
runs daily and builds only when there is something new: a colibri release,
a new CUDA major version in Arch (the engines link `libcudart.so.<major>`),
a manual run with *force*, or a push to `colibri-cuda-bin/build.sh`. It
compiles in an `archlinux:base-devel` container (`build.sh`), attaches the
result to a release of this repository (`colibri-cuda-bin-<pkgver>-<pkgrel>`)
and commits the new `PKGBUILD`/`.SRCINFO`. Installing is a download, as for
the other packages. Do not edit the version lines of that `PKGBUILD` by hand.

The build targets one machine: CUDA `sm_120` (RTX 50 series) and
`-march=znver5` (Ryzen 9000). Change both in `build.sh` for other hardware.
