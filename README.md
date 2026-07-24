# CloudPub РґР»СЏ OpenWrt

РџР°РєРµС‚С‹ РєР»РёРµРЅС‚Р° [CloudPub](https://cloudpub.ru) 3.2.2 РґР»СЏ OpenWrt СЃ СЃРµСЂРІРёСЃРѕРј procd, UCI-РєРѕРЅС„РёРіСѓСЂР°С†РёРµР№ Рё СЂСѓСЃСЃРєРёРј РІРµР±-РёРЅС‚РµСЂС„РµР№СЃРѕРј LuCI.

## Р‘С‹СЃС‚СЂР°СЏ СѓСЃС‚Р°РЅРѕРІРєР°

```sh
wget -qO- https://github.com/BrainDeLook/CloudPub-OpenWRT/releases/latest/download/install.sh | sh
```

РЈСЃС‚Р°РЅРѕРІС‰РёРє СЃР°Рј РѕРїСЂРµРґРµР»СЏРµС‚ Р°СЂС…РёС‚РµРєС‚СѓСЂСѓ Рё РїР°РєРµС‚РЅС‹Р№ РјРµРЅРµРґР¶РµСЂ:

- OpenWrt 24.10 Рё СЃС‚Р°СЂС€Рµ вЂ” РїР°РєРµС‚С‹ `.ipk` С‡РµСЂРµР· `opkg`;
- OpenWrt 25.12 Рё РЅРѕРІРµРµ вЂ” РїР°РєРµС‚С‹ `.apk` С‡РµСЂРµР· `apk`.

РџРѕСЃР»Рµ СѓСЃС‚Р°РЅРѕРІРєРё РѕС‚РєСЂРѕР№С‚Рµ **LuCI в†’ РЎР»СѓР¶Р±С‹ в†’ CloudPub**, СѓРєР°Р¶РёС‚Рµ С‚РѕРєРµРЅ Рё РґРѕР±Р°РІСЊС‚Рµ РїСѓР±Р»РёРєР°С†РёРё.

## РџРѕРґРґРµСЂР¶РёРІР°РµРјС‹Рµ Р°СЂС…РёС‚РµРєС‚СѓСЂС‹

| OpenWrt arch | РЎР±РѕСЂРєР° CloudPub |
|---|---|
| `aarch64_*` | `aarch64` static musl |
| `arm_cortex-a*`, `arm_arm1176*` | `arm` static musl |
| `arm_arm926ej-s`, `arm_xscale`, `arm_fa526` | `armv5te` static musl |
| `mipsel_24kc`, `mipsel_74kc`, `mipsel_mips32` | `mipsel` static |
| `x86_64` | `x86_64` (glibc; РјРѕР¶РµС‚ РЅРµ СЂР°Р±РѕС‚Р°С‚СЊ РЅР° musl) |

Big-endian MIPS (`mips_24kc`, РІРєР»СЋС‡Р°СЏ РјРЅРѕРіРёРµ ath79/ar71xx) РЅРµ РїРѕРґРґРµСЂР¶РёРІР°РµС‚СЃСЏ: CloudPub РЅРµ РїСѓР±Р»РёРєСѓРµС‚ РїРѕРґС…РѕРґСЏС‰РёР№ Р±РёРЅР°СЂРЅРёРє. РўСЂРµР±СѓРµС‚СЃСЏ РѕРєРѕР»Рѕ 10вЂ“15 РњР‘ СЃРІРѕР±РѕРґРЅРѕРіРѕ РјРµСЃС‚Р°.

## Р СѓС‡РЅР°СЏ СѓСЃС‚Р°РЅРѕРІРєР°

РЎРєР°С‡Р°Р№С‚Рµ РёР· [Releases](../../releases) РїР°РєРµС‚ `cloudpub` РґР»СЏ СЃРІРѕРµР№ Р°СЂС…РёС‚РµРєС‚СѓСЂС‹ Рё СѓРЅРёРІРµСЂСЃР°Р»СЊРЅС‹Р№ `luci-app-cloudpub`, Р·Р°С‚РµРј:

```sh
# OpenWrt 24.10 Рё СЃС‚Р°СЂС€Рµ
opkg install ./cloudpub_*.ipk ./luci-app-cloudpub_*.ipk

# OpenWrt 25.12 Рё РЅРѕРІРµРµ
apk add --allow-untrusted ./cloudpub-*.apk ./luci-app-cloudpub-*.apk
```

## РЎР±РѕСЂРєР°

РќР° Linux:

```sh
./build.sh
ARCHS="mipsel_24kc:mipsel" ./build.sh
CLO_VERSION=3.2.2 FORMATS="ipk apk" ./build.sh
```

Р”Р»СЏ `.apk` РЅСѓР¶РµРЅ `apk-tools` СЃ РєРѕРјР°РЅРґРѕР№ `apk mkpkg`; CI Р·Р°РїСѓСЃРєР°РµС‚ СЃР±РѕСЂРєСѓ РІ Alpine. РђСЂС‚РµС„Р°РєС‚С‹ Рё `SHA256SUMS` СЃРѕР·РґР°СЋС‚СЃСЏ РІ `bin/`.

РљР°С‚Р°Р»РѕРіРё `cloudpub/` Рё `luci-app-cloudpub/` С‚Р°РєР¶Рµ РјРѕР¶РЅРѕ РїРѕРґРєР»СЋС‡РёС‚СЊ РєР°Рє feed РёР»Рё СЃРєРѕРїРёСЂРѕРІР°С‚СЊ РІ `package/` OpenWrt SDK:

```sh
make package/cloudpub/compile package/luci-app-cloudpub/compile V=s
```

## РќР°СЃС‚СЂРѕР№РєР° С‡РµСЂРµР· SSH

```sh
uci set cloudpub.main.enabled='1'
uci set cloudpub.main.token='Р’РђРЁ_РўРћРљР•Рќ'
uci add cloudpub publish
uci set cloudpub.@publish[-1].proto='http'
uci set cloudpub.@publish[-1].target='192.168.1.1:80'
uci set cloudpub.@publish[-1].name='router-admin'
uci commit cloudpub
/etc/init.d/cloudpub restart
```

РђРєС‚РёРІРЅС‹Рµ РїСѓР±Р»РёРєР°С†РёРё:

```sh
clo -c /etc/cloudpub/client.toml ls
```

РЎРµСЂРІРёСЃ РїСЂРё СЃС‚Р°СЂС‚Рµ РїСЂРёРјРµРЅСЏРµС‚ С‚РѕРєРµРЅ, СЃРёРЅС…СЂРѕРЅРёР·РёСЂСѓРµС‚ UCI-РїСѓР±Р»РёРєР°С†РёРё Рё Р·Р°РїСѓСЃРєР°РµС‚ `clo run` РїРѕРґ procd СЃ Р°РІС‚РѕРїРµСЂРµР·Р°РїСѓСЃРєРѕРј.

## РЎСЃС‹Р»РєРё

- [Р”РѕРєСѓРјРµРЅС‚Р°С†РёСЏ CloudPub](https://cloudpub.ru/docs)
- [РСЃС‚РѕСЂРёСЏ РІРµСЂСЃРёР№ CloudPub](https://cloudpub.ru/docs/changelog)

