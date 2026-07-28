#!/bin/sh
set -eu

REPO="${REPO:-BrainDeLook/CloudPub-OpenWRT}"
VERSION="${VERSION:-3.3.0}"
PKG_RELEASE="${PKG_RELEASE:-1}"
LUCI_VERSION="${LUCI_VERSION:-1.1.0}"
BASE_URL="${BASE_URL:-https://github.com/$REPO/releases/download/v$VERSION}"
TMP="/tmp/cloudpub-install.$$"
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP"

say() { printf '%s\n' "$*"; }
die() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }
fetch() {
	if command -v uclient-fetch >/dev/null 2>&1; then
		uclient-fetch -q -O "$2" "$1"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "$2" "$1"
	elif command -v curl >/dev/null 2>&1; then
		curl -fsSL "$1" -o "$2"
	else
		die "нужен uclient-fetch, wget или curl"
	fi
}

[ -r /etc/openwrt_release ] || die "скрипт предназначен для OpenWrt"
. /etc/openwrt_release
ARCH="${DISTRIB_ARCH:-}"
[ -n "$ARCH" ] || die "не удалось определить архитектуру"

if command -v apk >/dev/null 2>&1; then
	PM="apk"
	EXT="apk"
	CLIENT_NAME="cloudpub-$VERSION-r$PKG_RELEASE-$ARCH.apk"
	LUCI_NAME="luci-app-cloudpub-$LUCI_VERSION-r$PKG_RELEASE.apk"
elif command -v opkg >/dev/null 2>&1; then
	PM="opkg"
	EXT="ipk"
	CLIENT_NAME="cloudpub_$VERSION-$PKG_RELEASE"_"$ARCH.ipk"
	LUCI_NAME="luci-app-cloudpub_$LUCI_VERSION-$PKG_RELEASE"_"all.ipk"
else
	die "не найден пакетный менеджер apk или opkg"
fi

say "CloudPub $VERSION: OpenWrt ${DISTRIB_RELEASE:-unknown}, $ARCH, пакет .$EXT"
fetch "$BASE_URL/$CLIENT_NAME" "$TMP/cloudpub.$EXT" ||
	die "в релизе v$VERSION нет пакета $CLIENT_NAME"
fetch "$BASE_URL/$LUCI_NAME" "$TMP/luci-app-cloudpub.$EXT" ||
	die "в релизе v$VERSION нет пакета $LUCI_NAME"

if [ "$PM" = "apk" ]; then
	apk add --allow-untrusted "$TMP/cloudpub.apk" "$TMP/luci-app-cloudpub.apk"
else
	opkg install "$TMP/cloudpub.ipk" "$TMP/luci-app-cloudpub.ipk"
fi

say "Готово. Откройте LuCI → Службы → CloudPub или настройте /etc/config/cloudpub."
