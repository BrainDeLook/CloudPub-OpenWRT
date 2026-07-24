#!/bin/sh
set -eu

REPO="BrainDeLook/CloudPub-OpenWRT"
API="https://api.github.com/repos/$REPO/releases/latest"
TMP="/tmp/cloudpub-install.$$"
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP"

say() { printf '%s\n' "$*"; }
die() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }
fetch() {
	if command -v uclient-fetch >/dev/null 2>&1; then uclient-fetch -q -O "$2" "$1"
	elif command -v wget >/dev/null 2>&1; then wget -q -O "$2" "$1"
	elif command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
	else die "нужен uclient-fetch, wget или curl"; fi
}

[ -r /etc/openwrt_release ] || die "скрипт предназначен для OpenWrt"
. /etc/openwrt_release
ARCH="${DISTRIB_ARCH:-}"
[ -n "$ARCH" ] || die "не удалось определить архитектуру"

if command -v apk >/dev/null 2>&1; then
	PM=apk; EXT=apk
elif command -v opkg >/dev/null 2>&1; then
	PM=opkg; EXT=ipk
else
	die "не найден пакетный менеджер apk или opkg"
fi

say "CloudPub: OpenWrt ${DISTRIB_RELEASE:-unknown}, $ARCH, пакет .$EXT"
fetch "$API" "$TMP/release.json"

asset_url() {
	sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\)".*/\1/p' "$TMP/release.json" |
		grep "$1" | head -n1
}

if [ "$EXT" = ipk ]; then
	CLIENT_PATTERN="cloudpub_.*_${ARCH}\.ipk"
	LUCI_PATTERN="luci-app-cloudpub_.*_all\.ipk"
else
	CLIENT_PATTERN="cloudpub-.*-${ARCH}\.apk"
	LUCI_PATTERN="luci-app-cloudpub-.*\.apk"
fi

CLIENT_URL="$(asset_url "$CLIENT_PATTERN")"
LUCI_URL="$(asset_url "$LUCI_PATTERN")"
[ -n "$CLIENT_URL" ] || die "в последнем релизе нет пакета для $ARCH"
[ -n "$LUCI_URL" ] || die "в последнем релизе нет пакета LuCI"
fetch "$CLIENT_URL" "$TMP/cloudpub.$EXT"
fetch "$LUCI_URL" "$TMP/luci-app-cloudpub.$EXT"

if [ "$PM" = apk ]; then
	apk add --allow-untrusted "$TMP/cloudpub.apk" "$TMP/luci-app-cloudpub.apk"
else
	opkg install "$TMP/cloudpub.ipk" "$TMP/luci-app-cloudpub.ipk"
fi

say "Готово. Откройте LuCI → Службы → CloudPub или настройте /etc/config/cloudpub."

