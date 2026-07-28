#!/usr/bin/env bash
set -euo pipefail

CLO_VERSION="${CLO_VERSION:-3.3.0}"
PKG_RELEASE="${PKG_RELEASE:-2}"
LUCI_VERSION="${LUCI_VERSION:-1.2.0}"
FORMATS="${FORMATS:-ipk apk}"
DL_URL="https://cloudpub.ru/download/stable"
MAINTAINER="CloudPub-OpenWRT"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="$ROOT/bin"
DL="$ROOT/dl"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

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

log() { printf '\033[1;32m>>> %s\033[0m\n' "$*" >&2; }
warn() { printf '\033[1;33m!!! %s\033[0m\n' "$*" >&2; }
want_format() { case " $FORMATS " in *" $1 "*) return 0;; *) return 1;; esac; }
mkdir -p "$BIN" "$DL"
rm -f "$BIN"/*.ipk "$BIN"/*.apk "$BIN/release"

pack_ipk() {
	local stage="$1" out="$2"
	( cd "$stage/control" && tar --owner=0 --group=0 --numeric-owner -czf "$stage/control.tar.gz" . )
	( cd "$stage/data" && tar --owner=0 --group=0 --numeric-owner -czf "$stage/data.tar.gz" . )
	echo "2.0" > "$stage/debian-binary"
	( cd "$stage" && tar --owner=0 --group=0 --numeric-owner -czf "$out" ./debian-binary ./control.tar.gz ./data.tar.gz )
	log "built $(basename "$out")"
}

pack_apk() {
	local stage="$1" out="$2" name="$3" version="$4" arch="$5" description="$6" depends="${7:-}"
	command -v apk >/dev/null 2>&1 || {
		warn "apk-tools is required for .apk output (set FORMATS=ipk to skip)"
		return 1
	}
	set -- apk mkpkg \
		--info "name:$name" --info "version:$version-r$PKG_RELEASE" \
		--info "description:$description" --info "arch:$arch" \
		--info "license:Apache-2.0" --info "origin:CloudPub-OpenWRT" \
		--info "url:https://github.com/BrainDeLook/CloudPub-OpenWRT" \
		--info "maintainer:$MAINTAINER"
	[ -z "$depends" ] || set -- "$@" --info "depends:$depends"
	[ ! -f "$stage/post-install" ] || set -- "$@" --script "post-install:$stage/post-install"
	[ ! -f "$stage/pre-deinstall" ] || set -- "$@" --script "pre-deinstall:$stage/pre-deinstall"
	"$@" --files "$stage/data" --output "$out"
	log "built $(basename "$out")"
}

fetch_clo() {
	local clo_arch="$1" tarball="clo-$CLO_VERSION-stable-linux-$1.tar.gz"
	local dest="$DL/$tarball"
	if [ ! -s "$dest" ]; then
		log "downloading $tarball"
		curl -fL --retry 3 --retry-delay 2 -o "$dest.tmp" "$DL_URL/$tarball"
		mv "$dest.tmp" "$dest"
	fi
	echo "$dest"
}

extract_clo() {
	local tarball="$1" dir="$2" bin
	mkdir -p "$dir"
	tar -xzf "$tarball" -C "$dir"
	bin="$(find "$dir" -type f -name clo | head -n1)"
	[ -n "$bin" ] || { warn "clo binary not found in $tarball"; return 1; }
	echo "$bin"
}

prepare_cloudpub() {
	local owrt_arch="$1" clo_bin="$2" stage="$WORK/cloudpub-$1" data
	data="$stage/data"
	mkdir -p "$data/usr/bin" "$data/etc/init.d" "$data/etc/config" "$data/etc/cloudpub" "$stage/control"
	install -m 0755 "$clo_bin" "$data/usr/bin/clo"
	install -m 0755 "$ROOT/cloudpub/files/cloudpub.init" "$data/etc/init.d/cloudpub"
	install -m 0644 "$ROOT/cloudpub/files/cloudpub.config" "$data/etc/config/cloudpub"
	local size; size="$(du -sk "$data" | cut -f1)"
	cat > "$stage/control/control" <<-EOF
		Package: cloudpub
		Version: $CLO_VERSION-$PKG_RELEASE
		Architecture: $owrt_arch
		Maintainer: $MAINTAINER
		Section: net
		Priority: optional
		Installed-Size: $((size * 1024))
		Description: CloudPub tunnel client (clo)
		 Publishes local services through a secure tunnel.
	EOF
	echo "/etc/config/cloudpub" > "$stage/control/conffiles"
	cat > "$stage/control/postinst" <<-'EOF'
		#!/bin/sh
		[ -n "${IPKG_INSTROOT:-}" ] || { /etc/init.d/cloudpub enable; /etc/init.d/cloudpub start; }
		exit 0
	EOF
	cat > "$stage/control/prerm" <<-'EOF'
		#!/bin/sh
		[ -n "${IPKG_INSTROOT:-}" ] || { /etc/init.d/cloudpub stop 2>/dev/null; /etc/init.d/cloudpub disable 2>/dev/null; }
		exit 0
	EOF
	cp "$stage/control/postinst" "$stage/post-install"
	cp "$stage/control/prerm" "$stage/pre-deinstall"
	chmod 0755 "$stage/control/postinst" "$stage/control/prerm" "$stage/post-install" "$stage/pre-deinstall"
	echo "$stage"
}

prepare_luci() {
	local stage="$WORK/luci-app-cloudpub" data="$WORK/luci-app-cloudpub/data" app="$ROOT/luci-app-cloudpub"
	mkdir -p "$data/www" "$stage/control"
	cp -a "$app/htdocs/." "$data/www/"
	cp -a "$app/root/." "$data/"
	if command -v po2lmo >/dev/null 2>&1; then
		mkdir -p "$data/usr/lib/lua/luci/i18n"
		po2lmo "$app/po/ru/cloudpub.po" "$data/usr/lib/lua/luci/i18n/cloudpub.ru.lmo"
	fi
	local size; size="$(du -sk "$data" | cut -f1)"
	cat > "$stage/control/control" <<-EOF
		Package: luci-app-cloudpub
		Version: $LUCI_VERSION-$PKG_RELEASE
		Architecture: all
		Maintainer: $MAINTAINER
		Section: luci
		Priority: optional
		Depends: cloudpub, luci-base
		Installed-Size: $((size * 1024))
		Description: LuCI support for CloudPub client
	EOF
	cat > "$stage/control/postinst" <<-'EOF'
		#!/bin/sh
		[ -n "${IPKG_INSTROOT:-}" ] || {
			rm -f /tmp/luci-indexcache*
			rm -rf /tmp/luci-modulecache/
			/etc/init.d/cloudpub-update-check enable
			/etc/init.d/cloudpub-update-check restart
			/etc/init.d/rpcd reload 2>/dev/null
		}
		exit 0
	EOF
	cat > "$stage/control/prerm" <<-'EOF'
		#!/bin/sh
		[ -n "${IPKG_INSTROOT:-}" ] || {
			/etc/init.d/cloudpub-update-check stop 2>/dev/null
			/etc/init.d/cloudpub-update-check disable 2>/dev/null
		}
		exit 0
	EOF
	chmod 0755 "$stage/control/postinst" "$stage/control/prerm"
	cp "$stage/control/postinst" "$stage/post-install"
	cp "$stage/control/prerm" "$stage/pre-deinstall"
	echo "$stage"
}

declare -A CLO_BINS
BUILT=0
for pair in $ARCHS; do
	owrt_arch="${pair%%:*}"; clo_arch="${pair##*:}"
	if [ -z "${CLO_BINS[$clo_arch]:-}" ]; then
		if tarball="$(fetch_clo "$clo_arch")" && bin="$(extract_clo "$tarball" "$WORK/clo-$clo_arch")"; then
			CLO_BINS[$clo_arch]="$bin"
			command -v file >/dev/null 2>&1 && log "$clo_arch: $(file -b "$bin")"
		else
			CLO_BINS[$clo_arch]="MISSING"
		fi
	fi
	[ "${CLO_BINS[$clo_arch]}" = MISSING ] && continue
	stage="$(prepare_cloudpub "$owrt_arch" "${CLO_BINS[$clo_arch]}")"
	want_format ipk && pack_ipk "$stage" "$BIN/cloudpub_${CLO_VERSION}-${PKG_RELEASE}_${owrt_arch}.ipk"
	want_format apk && pack_apk "$stage" "$BIN/cloudpub-${CLO_VERSION}-r${PKG_RELEASE}-${owrt_arch}.apk" cloudpub "$CLO_VERSION" "$owrt_arch" "CloudPub tunnel client"
	BUILT=$((BUILT + 1))
done
[ "$BUILT" -gt 0 ] || { warn "no client packages were built"; exit 1; }

stage="$(prepare_luci)"
want_format ipk && pack_ipk "$stage" "$BIN/luci-app-cloudpub_${LUCI_VERSION}-${PKG_RELEASE}_all.ipk"
want_format apk && pack_apk "$stage" "$BIN/luci-app-cloudpub-${LUCI_VERSION}-r${PKG_RELEASE}.apk" luci-app-cloudpub "$LUCI_VERSION" noarch "LuCI support for CloudPub" "cloudpub luci-base"
cp "$ROOT/luci-app-cloudpub/root/usr/share/cloudpub-openwrt/release" "$BIN/release"
log "done, packages are in $BIN"
ls -la "$BIN"

