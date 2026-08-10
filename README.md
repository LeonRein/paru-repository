# aur-repository

A personal Arch Linux package repository. PKGBUILDs live in [`pkgbuilds/`](pkgbuilds/);
CI builds them and publishes the finished packages plus the pacman database to
the orphan [`repo`](../../tree/repo) branch, so `paru`/`pacman` can install them
as ordinary binary packages — no local compiling, no AUR round-trip.

Packages here prefer prebuilt upstream release assets over building from source.
`transparent-xcursor-theme`, for example, is built by its own repository's CI and
published as a release tarball; this PKGBUILD only unpacks it, so it declares no
`makedepends` and has no `build()` function at all.

| Package | Description |
| --- | --- |
| [`transparent-xcursor-theme`](pkgbuilds/transparent-xcursor-theme) | Fully transparent Xcursor theme, for hiding the pointer in cage/kiosk sessions |

## Adding the repository

Append this to the **end** of `/etc/pacman.conf`:

```ini
[leonrein]
SigLevel = Optional TrustAll
Server = https://raw.githubusercontent.com/LeonRein/aur-repository/repo/$arch
```

Leave `$arch` literal — pacman substitutes it. Then:

```sh
sudo pacman -Sy
paru -S transparent-xcursor-theme
```

`paru` treats this like any other repository, so `paru -Syu` keeps the package
updated and `paru -S` prefers it over an AUR build of the same name.

Two notes on this URL:

- `raw.githubusercontent.com` caches for a few minutes, so a fresh build can
  take a moment to show up. If `pacman -Sy` reports a stale database, wait and
  retry rather than assuming the build failed.
- `SigLevel = Optional TrustAll` accepts unsigned packages. That is the right
  setting for a repository you build yourself and reach over HTTPS; see
  [Signing packages](#signing-packages-optional) to tighten it.

### Alternative: GitHub Pages

If you enable Pages for the `repo` branch, the same repository is also reachable
at a nicer URL with better caching behaviour:

```ini
Server = https://leonrein.github.io/aur-repository/$arch
```

## Building locally

You do not need CI. On any Arch machine, as a normal user with sudo rights:

```sh
./scripts/build-repo.sh                          # every package
./scripts/build-repo.sh transparent-xcursor-theme  # just one
```

This drops the packages and the `leonrein.db` database into `x86_64/`. Point
pacman at that directory to use it without publishing anything:

```ini
[leonrein]
SigLevel = Optional TrustAll
Server = file:///home/leon/aur-repository/x86_64
```

To install a single package without any repository at all:

```sh
cd pkgbuilds/transparent-xcursor-theme
makepkg -si
```

## Adding a package

1. Create `pkgbuilds/<name>/PKGBUILD`.
2. Generate its metadata: `cd pkgbuilds/<name> && makepkg --printsrcinfo > .SRCINFO`.
   CI fails the build if `.SRCINFO` and `PKGBUILD` disagree.
3. Commit and push. The `build-repo` workflow rebuilds everything and republishes
   the `repo` branch.

Prefer a prebuilt release asset with a real `sha256sums` entry. Failing that,
pin a git source by commit (`#commit=<sha>`) rather than by branch or tag: a
commit cannot be moved afterwards, so a rebuild always produces the same package.

## Updating a package

Bump `pkgver`, update `sha256sums` to the new release's checksum, reset
`pkgrel=1`, then regenerate `.SRCINFO` and push. Changing only the packaging and
not the upstream version means keeping `pkgver` and incrementing `pkgrel`
instead.

For `transparent-xcursor-theme` the checksum comes straight from its release
workflow: the run summary prints the exact `pkgver` and `sha256sums` lines to
paste in. `updpkgsums` (from `pacman-contrib`) recomputes them locally.

## Signing packages (optional)

Set `GPGKEY` and the build script signs both the packages and the database:

```sh
GPGKEY=<your-key-id> ./scripts/build-repo.sh
```

Then import the key on each client (`sudo pacman-key --recv-keys <id>` and
`sudo pacman-key --lsign-key <id>`) and tighten `pacman.conf` to
`SigLevel = Required DatabaseOptional`. For CI you would need to add the private
key as a repository secret and import it before the build step.

## How publishing works

`scripts/build-repo.sh` runs `makepkg` for each PKGBUILD with `PKGDEST` pointed
at the output directory, then `repo-add` to build the database. One detail is
worth knowing if you ever host this differently: `repo-add` leaves `leonrein.db`
as a *symlink* to `leonrein.db.tar.zst`. Git stores that symlink as a small text
file containing the target name, and a plain HTTP host serves exactly those
bytes — pacman would download the string `leonrein.db.tar.zst` and fail to parse
it as a database. The script therefore replaces both `.db` and `.files` with
real copies before publishing.

The `repo` branch is force-pushed on every build rather than appended to, so
git history does not accumulate every version of every binary package ever
built. Do not commit to it by hand; anything there is overwritten.
