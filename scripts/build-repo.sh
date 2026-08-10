#!/usr/bin/env bash
#
# Build every PKGBUILD under pkgbuilds/ and assemble a pacman repository
# database from the results.
#
#   ./scripts/build-repo.sh                 # build everything
#   ./scripts/build-repo.sh transparent-xcursor-theme
#
# Environment:
#   REPO_NAME  database name, must match the [section] in pacman.conf (default: leonrein)
#   OUTDIR     where packages and the database are written (default: <repo>/$(uname -m))
#   GPGKEY     if set, packages and the database are signed with this key
#
# Must run on Arch (or an Arch container) as a non-root user with sudo rights,
# because makepkg refuses to run as root.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_NAME="${REPO_NAME:-leonrein}"
OUTDIR="${OUTDIR:-$REPO_ROOT/$(uname -m)}"
DB_EXT="db.tar.zst"
FILES_EXT="files.tar.zst"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }

[[ $EUID -ne 0 ]] || die "makepkg refuses to run as root; run this as a normal user with sudo rights"
command -v makepkg >/dev/null || die "makepkg not found; this script needs to run on Arch Linux"
command -v repo-add >/dev/null || die "repo-add not found; install pacman"

# Positional arguments select individual packages; no arguments means all.
if (($#)); then
	targets=()
	for name in "$@"; do
		[[ -d $REPO_ROOT/pkgbuilds/$name ]] || die "no such package: pkgbuilds/$name"
		targets+=("$REPO_ROOT/pkgbuilds/$name")
	done
else
	mapfile -t targets < <(find "$REPO_ROOT/pkgbuilds" -mindepth 1 -maxdepth 1 -type d | sort)
	((${#targets[@]})) || die "pkgbuilds/ contains no packages"
fi

mkdir -p "$OUTDIR"

makepkg_opts=(--syncdeps --noconfirm --cleanbuild --force --needed)
repo_add_opts=(--new --remove --quiet)
if [[ -n ${GPGKEY:-} ]]; then
	makepkg_opts+=(--sign --key "$GPGKEY")
	repo_add_opts+=(--sign --key "$GPGKEY")
	export GPGKEY
fi

for target in "${targets[@]}"; do
	info "building $(basename "$target")"
	# PKGDEST puts the finished package straight into the repository directory.
	( cd "$target" && PKGDEST="$OUTDIR" makepkg "${makepkg_opts[@]}" )
done

shopt -s nullglob
packages=("$OUTDIR"/*.pkg.tar.zst)
shopt -u nullglob
((${#packages[@]})) || die "no packages were produced in $OUTDIR"

info "updating $REPO_NAME database with ${#packages[@]} package(s)"
repo-add "${repo_add_opts[@]}" "$OUTDIR/$REPO_NAME.$DB_EXT" "${packages[@]}"

# repo-add leaves `foo.db` as a symlink to `foo.db.tar.zst`. That is fine on a
# real file server, but this repository is published over plain HTTP from a git
# branch, where a symlink is served as a small text file containing its target
# and pacman would download that instead of the database. Materialise real
# copies so the published tree works regardless of how it is hosted.
for pair in "$DB_EXT:db" "$FILES_EXT:files"; do
	src="$OUTDIR/$REPO_NAME.${pair%%:*}"
	dst="$OUTDIR/$REPO_NAME.${pair##*:}"
	[[ -e $src ]] || continue
	cp -f --remove-destination "$src" "$dst"
	if [[ -e $src.sig ]]; then
		cp -f --remove-destination "$src.sig" "$dst.sig"
	fi
done

info "repository ready in $OUTDIR"
ls -1 "$OUTDIR"
