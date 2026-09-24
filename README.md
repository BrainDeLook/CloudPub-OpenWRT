# CloudPub для OpenWrt

Интеграция CloudPub для маршрутизаторов на OpenWrt. Она позволяет публиковать локальные сервисы в интернете через защищённый туннель CloudPub и управлять публикациями из LuCI.

[![Последний стабильный релиз](https://img.shields.io/github/v/release/BrainDeLook/CloudPub-OpenWRT?label=stable)](https://github.com/BrainDeLook/CloudPub-OpenWRT/releases/latest)
[![Сборка](https://img.shields.io/github/actions/workflow/status/BrainDeLook/CloudPub-OpenWRT/build.yml?label=build)](https://github.com/BrainDeLook/CloudPub-OpenWRT/actions)

## Возможности

- публикация HTTP, HTTPS, TCP, UDP, WebDAV, Minecraft, RTSP и 1C-сервисов;
- управление токеном, публикациями и службой через LuCI;
- автоматическая регистрация и восстановление публикаций после перезагрузки роутера;
- сохранение назначенных доменов при добавлении и удалении других публикаций;
- точное сопоставление публикаций по GUID и адресу, включая несколько сервисов на одном хосте;
- автоматический перезапуск CloudPub после применения настроек;
- проверка и установка стабильных обновлений прямо из LuCI;
- поддержка OpenWrt 25.12.5 и более старых выпусков OpenWrt.

## Установка

### Быстрая установка

Установщик сам определяет архитектуру роутера и выбирает подходящий пакетный менеджер:

```sh
wget -qO- https://github.com/BrainDeLook/CloudPub-OpenWRT/releases/latest/download/install.sh | sh
```

После установки откройте **LuCI → Службы → CloudPub**, вставьте API-токен и добавьте публикации.

### Ручная установка пакетов

Архитектуру можно проверить так:

```sh
. /etc/openwrt_release
echo "$DISTRIB_ARCH"
```

Для OpenWrt 24.10 и старше используются пакеты `.ipk`:

```sh
opkg install ./cloudpub_*.ipk ./luci-app-cloudpub_*.ipk
```

Для OpenWrt 25.12 и новее используются пакеты `.apk`:

```sh
apk add --allow-untrusted ./cloudpub-*.apk ./luci-app-cloudpub-*.apk
```

Готовые файлы находятся в разделе [Releases](https://github.com/BrainDeLook/CloudPub-OpenWRT/releases).

## Настройка через LuCI

1. Получите API-токен в [личном кабинете CloudPub](https://cloudpub.ru/dashboard).
2. Откройте **Службы → CloudPub**.
3. Вставьте токен и включите службу.
4. В разделе **Публикации** добавьте локальные сервисы, указав протокол, имя и адрес назначения, например `192.168.1.10:8123`.
5. Нажмите **Сохранить и применить**.

После применения CloudPub перезапустится автоматически. Публичные адреса появятся в блоке **Активные публикации**. Названия и URL в этом блоке являются кликабельными.

## Настройка через SSH

```sh
uci set cloudpub.main.enabled='1'
uci set cloudpub.main.token='ВАШ_ТОКЕН'

uci add cloudpub publish
uci set cloudpub.@publish[-1].enabled='1'
uci set cloudpub.@publish[-1].proto='http'
uci set cloudpub.@publish[-1].target='192.168.1.1:80'
uci set cloudpub.@publish[-1].name='OpenWRT'

uci commit cloudpub
/etc/init.d/cloudpub restart
```

Список активных публикаций:

```sh
/usr/bin/clo --conf /etc/cloudpub/client.toml ls
```

Логи службы:

```sh
logread -e cloudpub
```

## Конфигурация UCI

Основные параметры в `/etc/config/cloudpub`:

| Параметр | По умолчанию | Описание |
|---|---:|---|
| `enabled` | `0` | включение службы |
| `token` | — | API-токен CloudPub |
| `log_level` | `info` | уровень логирования: `error`, `warn`, `info`, `debug` |
| `unsafe_tls` | `0` | отключение проверки TLS-сертификата, только для self-hosted-серверов |

Параметры секции `publish`:

| Параметр | Описание |
|---|---|
| `enabled` | включение публикации, по умолчанию `1`; выключение останавливает туннель, но сохраняет его GUID и домен |
| `proto` | `http`, `https`, `tcp`, `udp`, `webdav`, `minecraft`, `rtsp` или `1c` |
| `target` | локальный порт, адрес `хост:порт` или путь |
| `name` | отображаемое имя публикации |
| `auth` | выбирается при создании: `none`, `basic` или `form`; форма доступна для HTTP, HTTPS, 1C и WebDAV (для WebDAV — только через браузер) |
| `acl` | задаются при создании в формате `email:роль`; роль `writer` — только для WebDAV |
| `header` | дополнительные HTTP-заголовки в формате `Имя:Значение` |

Авторизацию и ACL существующей публикации изменяйте в панели CloudPub: повторное сохранение секции LuCI не меняет их на сервере и не пересоздаёт публикацию, чтобы сохранить её домен.

## Сохранение публикаций

Состояние связок между UCI-публикациями и GUID CloudPub хранится в:

```text
/etc/cloudpub/publications.state
```

При изменении конфигурации служба сопоставляет публикации по протоколу, локальному адресу и сохранённому GUID. Поэтому удаление одной записи не должно менять домены остальных публикаций.

Не смешивайте публикации, созданные вручную командами `clo register` или `clo publish`, с публикациями из LuCI: UCI-конфигурация является источником истины для этого пакета.

## Поддерживаемые архитектуры

| Архитектура OpenWrt | Сборка клиента |
|---|---|
| `aarch64_*` | `aarch64` |
| `arm_cortex-a*`, `arm_arm1176*` | `arm` |
| `arm_arm926ej-s`, `arm_xscale`, `arm_fa526` | `armv5te` |
| `mipsel_24kc`, `mipsel_74kc`, `mipsel_mips32` | `mipsel` |
| `x86_64` | `x86_64` |

Big-endian MIPS (`mips_24kc`, многие ath79/ar71xx) не поддерживается клиентом CloudPub. Для установки требуется примерно 10–15 МБ свободного места.

## Сборка

Для самостоятельной сборки на Linux:

```sh
./build.sh
ARCHS="mipsel_24kc:mipsel" ./build.sh
CLO_VERSION=3.5.1056 ./build.sh
```

Пакеты также можно собрать через OpenWrt SDK:

```sh
make package/cloudpub/compile package/luci-app-cloudpub/compile V=s
```

## Ссылки

- [Личный кабинет CloudPub](https://cloudpub.ru/dashboard)
- [Документация CloudPub](https://cloudpub.ru/docs)
- [Тарифы CloudPub](https://cloudpub.ru/plans/)
- [История релизов](https://github.com/BrainDeLook/CloudPub-OpenWRT/releases)
- [Исходный код клиента CloudPub](https://github.com/ermak-dev/cloudpub)

## Уведомление

Данное приложение для OpenWrt является неофициальным и не связано с CloudPub. CloudPub — это сервис, предоставляемый его разработчиками.

Приложение не является официальным продуктом CloudPub и не поддерживается командой CloudPub. Ответственность за изменения в API CloudPub или возможное прекращение работы сервиса не лежит на разработчике приложения.

Информация о тарифах CloudPub предоставлена исключительно в справочных целях. Актуальные условия, цены и ограничения всегда доступны на официальном сайте [CloudPub](https://cloudpub.ru/plans/).
