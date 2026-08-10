# aur-repository

A personal [paru](https://github.com/Morganamilo/paru) **PKGBUILD repository** —
a git repo full of PKGBUILDs that paru treats just like the AUR, so packages
here can be installed and upgraded with the same commands.

| Package | Description |
| --- | --- |
| [`transparent-xcursor-theme`](transparent-xcursor-theme) | Fully transparent Xcursor theme, for hiding the pointer in cage/kiosk sessions |

Nothing here is compiled on your machine. Each package installs a prebuilt
release asset, so no build tooling is pulled in — installing
`transparent-xcursor-theme` does **not** require `xcursorgen` or ImageMagick.
Those run once in the theme repository's own CI.

## Adding the repository

Requires **paru 2.0 or newer**. Add to `/etc/paru.conf` (or
`~/.config/paru/paru.conf`):

```ini
[leonrein]
Url = https://github.com/LeonRein/aur-repository.git
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
Url = https://github.com/LeonRein/aur-repository.git
SkipReview = true      # skip the diff review prompt for your own PKGBUILDs
Depth = 3              # how deep to scan for PKGBUILDs; 3 is the default
```

- `Path = /home/leon/aur-repository` points at a local clone instead of a URL,
  which is handy while editing a PKGBUILD.
- PKGBUILD repos take **priority over the AUR**, so a package here masks an AUR
  package of the same name. Useful deliberately, surprising by accident.

## Installing without paru

Every package directory is a normal PKGBUILD, so `makepkg` works directly:

```sh
git clone https://github.com/LeonRein/aur-repository.git
cd aur-repository/transparent-xcursor-theme
makepkg -si
```

## Adding a package

1. Create `<name>/PKGBUILD`. Keep one directory per package at the repository
   root — paru scans recursively, three levels deep by default.
2. Generate its metadata: `cd <name> && makepkg --printsrcinfo > .SRCINFO`.
   CI fails if `.SRCINFO` and `PKGBUILD` disagree.
3. Commit and push, then `paru -Sy --pkgbuilds` on any machine using the repo.

Prefer a prebuilt release asset with a real `sha256sums` entry, so installing
stays a download-and-copy rather than a build. Where something genuinely has to
be built from source, pin the source by commit (`#commit=<sha>`) rather than by
branch or tag — a commit cannot be moved afterwards.

## Updating a package

Bump `pkgver`, update `sha256sums` to the new release's checksum, reset
`pkgrel=1`, regenerate `.SRCINFO`, and push. Changing only the packaging and not
the upstream version means keeping `pkgver` and incrementing `pkgrel` instead.

For `transparent-xcursor-theme` the checksum comes straight from its release
workflow: the run summary prints the exact `pkgver` and `sha256sums` lines to
paste in. `updpkgsums` (from `pacman-contrib`) recomputes them locally.

## CI

[`validate.yml`](.github/workflows/validate.yml) runs `makepkg` on every package
in an Arch container exactly as paru would, then unpacks the result and checks
that the theme landed in the right place and that its ~168 cursor aliases
survived packaging as symlinks rather than being expanded into copies. It also
verifies `.SRCINFO` has not drifted from its `PKGBUILD`.
