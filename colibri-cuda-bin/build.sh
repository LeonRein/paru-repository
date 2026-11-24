#!/usr/bin/env bash
# Builds colibri with CUDA + Vulkan inside an archlinux:base-devel container
# and updates PKGBUILD/.SRCINFO for the result. Run by
# .github/workflows/colibri-cuda-bin.yml; not meant to run on a desktop.
#
#   build.sh <upstream tag> <pkgver> <pkgrel> <cuda major>
#
# Output: out/colibri-cuda-bin-<pkgver>-<pkgrel>-x86_64.tar.zst, holding the
# usr/ tree the PKGBUILD copies into the package as-is.
set -euo pipefail

tag=$1 ver=$2 rel=$3 cudamajor=$4
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
name=colibri-cuda-bin
asset=$name-$ver-$rel-x86_64.tar.zst

pacman -Syu --noconfirm --needed cuda shaderc vulkan-headers python git

# /etc/profile.d/cuda.sh puts nvcc on PATH and sets NVCC_CCBIN to the GCC
# that this cuda release supports; it needs /etc/profile's helpers.
set +u
. /etc/profile
set -u
nvcc --version | tail -1
have=$(nvcc --version | sed -n 's/.*release \([0-9]*\)\..*/\1/p')
if [ "$have" != "$cudamajor" ]; then
  echo "expected CUDA $cudamajor, container has $have" >&2
  exit 1
fi

# Pin the source to the commit the tag points at, as the repo README asks.
commit=$(git ls-remote https://github.com/JustVugg/colibri.git "refs/tags/$tag^{}" | cut -f1)
[ -n "$commit" ] || commit=$(git ls-remote https://github.com/JustVugg/colibri.git "refs/tags/$tag" | cut -f1)
src=$(mktemp -d)
git -C "$src" init -q
git -C "$src" fetch -q --depth 1 https://github.com/JustVugg/colibri.git "$commit"
git -C "$src" checkout -q FETCH_HEAD
echo "colibri $tag = $commit"

# sm_120: RTX 50 series only. znver5: Ryzen 9000 (AVX-512); this package is
# built for one machine, not for distribution.
flags=(ARCH=znver5 CUDA=1 VK=1 CUDA_HOME=/opt/cuda CUDA_ARCH=sm_120
       PREFIX=/usr LIBEXECDIR=/usr/lib/colibri)
make -C "$src/c" -j"$(nproc)" "${flags[@]}" \
  colibri-tui colibri glm53 inkling kimi_k3 olmoe qwen36 qwen38 \
  deepseek_v41 mimo qwenimage laya gliner_decide

stage=$(mktemp -d)
make -C "$src/c" "${flags[@]}" DESTDIR="$stage" install

# coli derives its paths from realpath(__file__): the real file goes next to
# the engines, PATH gets a symlink.
install -Dm755 "$stage/usr/bin/coli" "$stage/usr/lib/colibri/coli"
rm -f "$stage/usr/bin/coli"
ln -s ../lib/colibri/coli "$stage/usr/bin/coli"
# The engines look for the Vulkan shaders in shaders/ next to themselves;
# the install target leaves them out.
install -dm755 "$stage/usr/lib/colibri/shaders"
install -m644 "$src"/c/shaders/*.spv "$stage/usr/lib/colibri/shaders/"
install -Dm644 "$src/LICENSE" "$stage/usr/share/licenses/$name/LICENSE"

mkdir -p "$root/out"
tar -C "$stage" --owner=0 --group=0 --numeric-owner --zstd -cf "$root/out/$asset" usr
sha=$(sha256sum "$root/out/$asset" | cut -d' ' -f1)
ls -l "$root/out/$asset"
echo "$commit" > "$root/out/commit"

sed -i \
  -e "s/^pkgver=.*/pkgver=$ver/" \
  -e "s/^pkgrel=.*/pkgrel=$rel/" \
  -e "s/^_cudamajor=.*/_cudamajor=$cudamajor/" \
  -e "s/^_commit=.*/_commit=$commit/" \
  -e "s/^sha256sums=.*/sha256sums=('$sha')/" \
  "$here/PKGBUILD"

# makepkg refuses to run as root, even for --printsrcinfo.
id builder >/dev/null 2>&1 || useradd -m builder
chown -R builder "$here"
su builder -c "cd '$here' && makepkg --printsrcinfo > .SRCINFO"

# Hand the files back to the runner's user.
chown -R "${HOST_UID:-1001}:${HOST_GID:-118}" "$here" "$root/out"
