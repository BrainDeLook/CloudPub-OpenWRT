#!/usr/bin/env bash
#
# Build .ipk packages for the CloudPub client and its LuCI app without
# the OpenWrt SDK. Prebuilt static clo binaries are downloaded from
# cloudpub.ru for every supported architecture.
#
# Usage:
#   ./build.sh                 build for all architectures from the list below
#   CLO_VERSION=3.1.0 ./build.sh
#   ARCHS="mipsel_24kc:mipsel" ./build.sh   build only the given pairs
#
# Output: bin/*.ipk
#
set -euo pipefail

CLO_VERSION="${CLO_VERSION:-3.1.0}"
PKG_RELEASE="${PKG_RELEASE:-1}"
LUCI_VERSION="${LUCI_VERSION:-1.0.0}"
DL_URL="https://cloudpub.ru/download/stable"
MAINTAINER="CloudPub-OpenWRT"

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="$ROOT/bin"
DL="$ROOT/dl"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# OpenWrt package architecture -> CloudPub build architecture.
# All CloudPub Linux builds except x86_64 are statically linked (musl),
# so one binary covers every CPU variant of the same family.
DEFAULT_ARCHS="
x86_64:x86_64
aarch64_generic:aarch64
aarch64_cortex-a53:aarch64
aarch64_cortex-a72:aarch64
aarch64_cortex-a76:aarch64
arm_cortex-a5_vfpv4:arm
arm_cortex-a7:arm
arm_cortex-a7_neon-vfpv4:arm
arm_cortex-a7_vfpv4:arm
arm_cortex-a8_vfpv3:arm
arm_cortex-a9:arm
arm_cortex-a9_neon:arm
arm_cortex-a9_vfpv3-d16:arm
arm_cortex-a15_neon-vfpv4:arm
arm_arm1176jzf-s_vfp:arm
arm_arm926ej-s:armv5te
arm_fa526:armv5te
arm_xscale:armv5te
mipsel_24kc:mipsel
mipsel_24kc_24kf:mipsel
mipsel_74kc:mipsel
mipsel_mips32:mipsel
"
ARCHS="${ARCHS:-$DEFAULT_ARCHS}"

log()  { printf '\033[1;32m>>> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!!! %s\033[0m\n' "$*" >&2; }

mkdir -p "$BIN" "$DL"

# Pack an ipk from prepared control/ and data/ directories.
# $1 = staging dir (contains control/ and data/), $2 = output file
pack_ipk() {
	local stage="$1" out="$2"
	( cd "$stage/control" && tar --owner=0 --group=0 --numeric-owner -czf "$stage/control.tar.gz" . )
	( cd "$stage/data"    && tar --owner=0 --group=0 --numeric-owner -czf "$stage/data.tar.gz" . )
	echo "2.0" > "$stage/debian-binary"
	( cd "$stage" && tar --owner=0 --group=0 --numeric-owner -czf "$out" \
		./debian-binary ./control.tar.gz ./data.tar.gz )
	log "built $(basename "$out")"
}

fetch_clo() {
	local clo_arch="$1"
	local tarball="clo-$CLO_VERSION-stable-linux-$clo_arch.tar.gz"
	local dest="$DL/$tarball"
	if [ ! -s "$dest" ]; then
		log "downloading $tarball"
		curl -fL --retry 3 --retry-delay 2 -o "$dest.tmp" "$DL_URL/$tarball"
		mv "$dest.tmp" "$dest"
	fi
	echo "$dest"
}

extract_clo() {
	local tarball="$1" dir="$2"
	mkdir -p "$dir"
	tar -xzf "$tarball" -C "$dir"
	local bin
	bin="$(find "$dir" -type f -name clo | head -n1)"
	[ -n "$bin" ] || { warn "clo binary not found in $tarball"; return 1; }
	echo "$bin"
}

build_cloudpub_ipk() {
	local owrt_arch="$1" clo_bin="$2"
	local stage="$WORK/cloudpub-$owrt_arch"
	local data="$stage/data" control="$stage/control"

	mkdir -p "$data/usr/bin" "$data/etc/init.d" "$data/etc/config" "$data/etc/cloudpub" "$control"

	install -m 0755 "$clo_bin" "$data/usr/bin/clo"
	install -m 0755 "$ROOT/cloudpub/files/cloudpub.init" "$data/etc/init.d/cloudpub"
	install -m 0644 "$ROOT/cloudpub/files/cloudpub.config" "$data/etc/config/cloudpub"

	local size
	size="$(du -sk "$data" | cut -f1)"

	cat > "$control/control" <<-EOF
		Package: cloudpub
		Version: $CLO_VERSION-$PKG_RELEASE
		Architecture: $owrt_arch
		Maintainer: $MAINTAINER
		Section: net
		Priority: optional
		Installed-Size: $((size * 1024))
		Description: CloudPub tunnel client (clo)
		 Publishes local services to the Internet through a secure tunnel.
		 Configured via UCI (/etc/config/cloudpub) and LuCI (luci-app-cloudpub).
	EOF

	cat > "$control/conffiles" <<-EOF
		/etc/config/cloudpub
	EOF

	cat > "$control/postinst" <<-'EOF'
		#!/bin/sh
		[ -n "${IPKG_INSTROOT}" ] || {
			/etc/init.d/cloudpub enable
			/etc/init.d/cloudpub start
		}
		exit 0
	EOF

	cat > "$control/prerm" <<-'EOF'
		#!/bin/sh
		[ -n "${IPKG_INSTROOT}" ] || {
			/etc/init.d/cloudpub stop 2>/dev/null
			/etc/init.d/cloudpub disable 2>/dev/null
		}
		exit 0
	EOF

	chmod 0755 "$control/postinst" "$control/prerm"
	pack_ipk "$stage" "$BIN/cloudpub_${CLO_VERSION}-${PKG_RELEASE}_${owrt_arch}.ipk"
}

build_luci_ipk() {
	local stage="$WORK/luci-app-cloudpub"
	local data="$stage/data" control="$stage/control"
	local app="$ROOT/luci-app-cloudpub"

	mkdir -p "$data/www" "$control"
	cp -a "$app/htdocs/." "$data/www/"
	cp -a "$app/root/." "$data/"

	# Compile the Russian translation when po2lmo is available
	if command -v po2lmo >/dev/null 2>&1; then
		mkdir -p "$data/usr/lib/lua/luci/i18n"
		po2lmo "$app/po/ru/cloudpub.po" "$data/usr/lib/lua/luci/i18n/cloudpub.ru.lmo"
		log "compiled Russian translation (cloudpub.ru.lmo)"
	else
		warn "po2lmo not found: LuCI interface will be in English (install po2lmo from openwrt/luci to include the Russian translation)"
	fi

	local size
	size="$(du -sk "$data" | cut -f1)"

	cat > "$control/control" <<-EOF
		Package: luci-app-cloudpub
		Version: $LUCI_VERSION-$PKG_RELEASE
		Architecture: all
		Maintainer: $MAINTAINER
		Section: luci
		Priority: optional
		Depends: cloudpub, luci-base
		Installed-Size: $((size * 1024))
		Description: LuCI support for CloudPub client
		 Web interface for the CloudPub tunnel client: API token,
		 publications and service status.
	EOF

	cat > "$control/postinst" <<-'EOF'
		#!/bin/sh
		[ -n "${IPKG_INSTROOT}" ] || {
			rm -f /tmp/luci-indexcache*
			rm -rf /tmp/luci-modulecache/
			/etc/init.d/rpcd reload 2>/dev/null
		}
		exit 0
	EOF

	cat > "$control/postrm" <<-'EOF'
		#!/bin/sh
		[ -n "${IPKG_INSTROOT}" ] || {
			rm -f /tmp/luci-indexcache*
			rm -rf /tmp/luci-modulecache/
		}
		exit 0
	EOF

	chmod 0755 "$control/postinst" "$control/postrm"
	pack_ipk "$stage" "$BIN/luci-app-cloudpub_${LUCI_VERSION}-${PKG_RELEASE}_all.ipk"
}

# --- main ---------------------------------------------------------------

declare -A CLO_BINS  # clo_arch -> extracted binary path
BUILT=0

for pair in $ARCHS; do
	owrt_arch="${pair%%:*}"
	clo_arch="${pair##*:}"

	if [ -z "${CLO_BINS[$clo_arch]:-}" ]; then
		if ! tarball="$(fetch_clo "$clo_arch")"; then
			warn "download failed for $clo_arch, skipping all $clo_arch targets"
			CLO_BINS[$clo_arch]="MISSING"
			continue
		fi
		if ! bin="$(extract_clo "$tarball" "$WORK/clo-$clo_arch")"; then
			CLO_BINS[$clo_arch]="MISSING"
			continue
		fi
		CLO_BINS[$clo_arch]="$bin"

		if command -v file >/dev/null 2>&1; then
			info="$(file -b "$bin")"
			log "$clo_arch: $info"
			case "$info" in
				*dynamically*)
					warn "$clo_arch build is dynamically linked (glibc) and will most likely NOT run on OpenWrt (musl)."
					;;
			esac
		fi
	fi

	[ "${CLO_BINS[$clo_arch]}" = "MISSING" ] && continue
	build_cloudpub_ipk "$owrt_arch" "${CLO_BINS[$clo_arch]}"
	BUILT=$((BUILT + 1))
done

if [ "$BUILT" -eq 0 ]; then
	warn "no cloudpub packages were built (all downloads failed?)"
	exit 1
fi

build_luci_ipk

log "done, packages are in $BIN"
ls -la "$BIN"
