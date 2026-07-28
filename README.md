# CloudPub для OpenWrt

Пакеты клиента [CloudPub](https://cloudpub.ru) 3.3.0 для OpenWrt с сервисом procd, UCI-конфигурацией и русским веб-интерфейсом LuCI.

## Быстрая установка

```sh
wget -qO- https://github.com/BrainDeLook/CloudPub-OpenWRT/releases/latest/download/install.sh | sh
```

Установщик сам определяет архитектуру и пакетный менеджер:

- OpenWrt 24.10 и старше — пакеты `.ipk` через `opkg`;
- OpenWrt 25.12 и новее — пакеты `.apk` через `apk`.

После установки откройте **LuCI → Службы → CloudPub**, укажите токен и добавьте публикации.

Аддон автоматически проверяет наличие новой версии при запуске и затем каждые 24 часа. Кнопка **Проверить обновления** запускает проверку вручную, а кнопка **Обновить аддон** появляется только при наличии нового релиза и устанавливает подходящие пакеты клиента и LuCI.

## Поддерживаемые архитектуры

| OpenWrt arch | Сборка CloudPub |
|---|---|
| `aarch64_*` | `aarch64` static musl |
| `arm_cortex-a*`, `arm_arm1176*` | `arm` static musl |
| `arm_arm926ej-s`, `arm_xscale`, `arm_fa526` | `armv5te` static musl |
| `mipsel_24kc`, `mipsel_74kc`, `mipsel_mips32` | `mipsel` static |
| `x86_64` | `x86_64` (glibc; может не работать на musl) |

Big-endian MIPS (`mips_24kc`, включая многие ath79/ar71xx) не поддерживается: CloudPub не публикует подходящий бинарник. Требуется около 10–15 МБ свободного места.

## Ручная установка

Скачайте из [Releases](../../releases) пакет `cloudpub` для своей архитектуры и универсальный `luci-app-cloudpub`, затем:

```sh
# OpenWrt 24.10 и старше
opkg install ./cloudpub_*.ipk ./luci-app-cloudpub_*.ipk

# OpenWrt 25.12 и новее
apk add --allow-untrusted ./cloudpub-*.apk ./luci-app-cloudpub-*.apk
```

## Сборка

На Linux:

```sh
./build.sh
ARCHS="mipsel_24kc:mipsel" ./build.sh
CLO_VERSION=3.3.0 FORMATS="ipk apk" ./build.sh
```

Для `.apk` нужен `apk-tools` с командой `apk mkpkg`; CI запускает сборку в Alpine. Артефакты и `SHA256SUMS` создаются в `bin/`.

Версия OpenWrt-релиза хранится в `luci-app-cloudpub/root/usr/share/cloudpub-openwrt/release`. Этот файл публикуется вместе с пакетами и используется фоновой службой проверки обновлений.

Каталоги `cloudpub/` и `luci-app-cloudpub/` также можно подключить как feed или скопировать в `package/` OpenWrt SDK:

```sh
make package/cloudpub/compile package/luci-app-cloudpub/compile V=s
```

## Настройка через SSH

```sh
uci set cloudpub.main.enabled='1'
uci set cloudpub.main.token='ВАШ_ТОКЕН'
uci add cloudpub publish
uci set cloudpub.@publish[-1].proto='http'
uci set cloudpub.@publish[-1].target='192.168.1.1:80'
uci set cloudpub.@publish[-1].name='router-admin'
uci commit cloudpub
/etc/init.d/cloudpub restart
```

Активные публикации:

```sh
clo -c /etc/cloudpub/client.toml ls
```

Сервис при старте применяет токен, синхронизирует UCI-публикации и запускает `clo run` под procd с автоперезапуском.

## Ссылки

- [Документация CloudPub](https://cloudpub.ru/docs)
- [История версий CloudPub](https://cloudpub.ru/docs/changelog)

