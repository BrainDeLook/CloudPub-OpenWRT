# CloudPub для OpenWrt

Пакеты OpenWrt для клиента [CloudPub](https://cloudpub.ru) — сервиса публикации локальных ресурсов в интернете через защищённый туннель (российская альтернатива ngrok).

В комплекте:

- **`cloudpub`** — клиент `clo`, init-скрипт (procd) и UCI-конфигурация `/etc/config/cloudpub`
- **`luci-app-cloudpub`** — веб-интерфейс LuCI: ввод API-токена, управление публикациями, статус службы и список активных публикаций (с русским переводом)

## Поддерживаемые архитектуры

| OpenWrt arch | Сборка CloudPub | Примеры устройств |
|---|---|---|
| `aarch64_*` | aarch64 (static musl) | большинство современных роутеров (Filogic, IPQ, RK) |
| `arm_cortex-a*`, `arm_arm1176*` | arm (static musl) | BCM27xx, imx, mvebu и др. |
| `arm_arm926ej-s`, `arm_xscale`, `arm_fa526` | armv5te (static musl) | старые ARMv5 |
| `mipsel_24kc`, `mipsel_74kc`, `mipsel_mips32` | mipsel (static) | MediaTek ramips (MT76xx) |
| `x86_64` | x86_64 | ПК/виртуалки ⚠️ |

⚠️ **Ограничения:**

- Сборка `x86_64` у CloudPub слинкована с glibc — на musl-системе OpenWrt она может не запуститься. Скрипт сборки проверяет это и предупреждает.
- Сборок под **big-endian MIPS** (`mips_24kc` — ath79/ar71xx, многие TP-Link/Ubiquiti) у CloudPub нет — эти устройства не поддерживаются.
- Учтите свободное место: бинарник `clo` занимает ~10+ МБ, на роутерах с 16 МБ флеша места не хватит.

## Установка

### Готовые пакеты

Скачайте из [Releases](../../releases) два файла и установите на роутере:

```sh
# архитектуру роутера смотрим так:
. /etc/openwrt_release; echo $DISTRIB_ARCH

opkg update
opkg install cloudpub_*_<ваша_архитектура>.ipk
opkg install luci-app-cloudpub_*_all.ipk
```

### Сборка ipk самостоятельно (без SDK)

На любой Linux-машине с `bash`, `curl`, `tar`:

```sh
./build.sh                     # все архитектуры
ARCHS="mipsel_24kc:mipsel" ./build.sh   # только нужная
CLO_VERSION=3.1.0 ./build.sh   # конкретная версия клиента
```

Готовые пакеты появятся в `bin/`. Если в системе есть `po2lmo` (из репозитория openwrt/luci), в пакет LuCI будет включён русский перевод.

### Сборка через OpenWrt SDK

Каталоги `cloudpub/` и `luci-app-cloudpub/` — обычные пакеты OpenWrt. Скопируйте их в `package/` вашего SDK (или подключите репозиторий как feed) и соберите:

```sh
make package/cloudpub/compile package/luci-app-cloudpub/compile V=s
```

## Настройка

### Через LuCI

1. Зарегистрируйтесь в [личном кабинете CloudPub](https://cloudpub.ru/dashboard) и скопируйте API-токен.
2. Откройте **Службы → CloudPub** (Services → CloudPub).
3. Вставьте токен, поставьте галочку **Включить**.
4. В разделе **Публикации** добавьте сервисы: протокол (HTTP, HTTPS, TCP, UDP, WebDAV, Minecraft, RTSP, 1C) и локальный адрес (`8080` или `192.168.1.10:8080`). При необходимости — аутентификация (Basic/Form) и правила доступа ACL.
5. Нажмите **Сохранить и применить**. Служба перезапустится, публикации зарегистрируются автоматически, а публичные URL появятся в блоке **Активные публикации**.

### Через SSH (UCI)

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

Публичные адреса можно посмотреть командой:

```sh
clo -c /etc/cloudpub/client.toml ls
```

### Опции `/etc/config/cloudpub`

Секция `main`:

| Опция | По умолчанию | Описание |
|---|---|---|
| `enabled` | `0` | включение службы |
| `token` | — | API-токен из личного кабинета |
| `log_level` | `info` | `error` / `warn` / `info` / `debug` (лог в syslog, `logread -e cloudpub`) |
| `unsafe_tls` | `0` | не проверять сертификат сервера (для self-hosted) |

Секции `publish` (одна на публикацию):

| Опция | Описание |
|---|---|
| `enabled` | включение публикации (по умолчанию `1`) |
| `proto` | `http`, `https`, `tcp`, `udp`, `webdav`, `minecraft`, `rtsp`, `1c` |
| `target` | порт, `хост:порт` или путь |
| `name` | название (необязательно) |
| `auth` | `none`, `basic`, `form` |
| `acl` | список правил `email:роль` (роли: `admin`, `reader`, `writer`) |
| `header` | список HTTP-заголовков `Имя:Значение` |

## Как это работает

Init-скрипт при запуске:

1. записывает токен в конфиг клиента (`clo set token`);
2. сравнивает набор публикаций из UCI с последним применённым (по контрольной сумме) и при изменении заново регистрирует их (`clo clean` + `clo register`);
3. запускает демона `clo run` под procd с автоперезапуском и логированием в syslog.

Публикации, созданные вручную через `clo publish`/`clo register` мимо UCI, будут удалены при следующем изменении публикаций в UCI — управляйте ими либо через LuCI/UCI, либо только вручную.

## Ссылки

- Клиент CloudPub (исходники): https://github.com/ermak-dev/cloudpub
- Документация CloudPub: https://cloudpub.ru/docs
