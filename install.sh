#!/bin/sh
set -eu

REPO="${REPO:-BrainDeLook/CloudPub-OpenWRT}"
RELEASE_TAG="${RELEASE_TAG:-@RELEASE_TAG@}"
VERSION="${VERSION:-3.5.1056}"
LUCI_VERSION="${LUCI_VERSION:-1.1.0}"
BASE_URL="${BASE_URL:-https://github.com/$REPO/releases/download/$RELEASE_TAG}"
TMP="/tmp/cloudpub-install.$$"
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP"

fetch() {
	local url="$1" out="$2"
	if command -v uclient-fetch >/dev/null 2>&1; then
		uclient-fetch -q -O "$out" "$url"
	elif command -v wget >/dev/null 2>&1; then
		wget -q -O "$out" "$url"
	elif command -v curl >/dev/null 2>&1; then
		curl -fsSL "$url" -o "$out"
	else
		echo "Ошибка: нужен uclient-fetch, wget или curl" >&2
		return 1
	fi
}

ARCH="${ARCH:-$(. /etc/openwrt_release 2>/dev/null && printf '%s' "${DISTRIB_ARCH:-}")}"
[ -n "$ARCH" ] || { echo "Ошибка: не удалось определить OpenWrt-архитектуру" >&2; exit 1; }

if command -v apk >/dev/null 2>&1 && [ -f /etc/openwrt_release ] && grep -q "DISTRIB_RELEASE='25\.12" /etc/openwrt_release; then
	CLIENT="cloudpub-${VERSION}-r1-${ARCH}.apk"
	LUCI="luci-app-cloudpub-${LUCI_VERSION}-r1.apk"
	fetch "$BASE_URL/$CLIENT" "$TMP/cloudpub.apk"
	fetch "$BASE_URL/$LUCI" "$TMP/luci-app-cloudpub.apk"
	apk add --allow-untrusted "$TMP/cloudpub.apk" "$TMP/luci-app-cloudpub.apk"
else
	CLIENT="cloudpub_${VERSION}-1_${ARCH}.ipk"
	LUCI="luci-app-cloudpub_${LUCI_VERSION}-1_all.ipk"
	fetch "$BASE_URL/$CLIENT" "$TMP/cloudpub.ipk"
	fetch "$BASE_URL/$LUCI" "$TMP/luci-app-cloudpub.ipk"
	opkg install "$TMP/cloudpub.ipk" "$TMP/luci-app-cloudpub.ipk"
fi

echo "CloudPub установлена: $RELEASE_TAG"
