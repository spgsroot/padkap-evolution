# padkap-evolution

[![Star](https://img.shields.io/github/stars/spgsroot/padkap-evolution?style=social)](https://github.com/spgsroot/padkap-evolution/stargazers)
[![Releases](https://img.shields.io/github/v/release/spgsroot/padkap-evolution?label=releases)](https://github.com/spgsroot/padkap-evolution/releases)

> **padkap-evolution** — форк [Forkop](https://github.com/ushan0v/forkop) (бывший Podkop Plus, форк [Podkop](https://github.com/itdoginfo/podkop)) с функциями, перенесёнными из [NetShift](https://github.com/yandexru45/netshift). Бэкенд — ucode, пакеты `forkop` / `luci-app-forkop`.

### Установка

Пакеты релизов апстрима Forkop:

```sh
sh <(wget -O - https://raw.githubusercontent.com/ushan0v/forkop/main/install.sh)
```

Сборка этого форка (ipk для OpenWrt 24.10, apk для 25.12+):

```sh
git clone https://github.com/spgsroot/padkap-evolution.git
cd padkap-evolution
bash build.sh 1.0.6
# OpenWrt 24.10 (opkg):
opkg install dist/release-final/forkop_*.ipk dist/release-final/luci-app-forkop_*.ipk
# OpenWrt 25.12+ (apk):
apk add dist/release-final/forkop_*.apk dist/release-final/luci-app-forkop_*.apk
```

Интерфейс появится в LuCI: **Services → Forkop**.

### Что нового в этом форке

* Поддержка подписок.
* Поддержка sing-box extended и транспорта XHTTP.
* Обновлённый LuCI-интерфейс.
* Расширенное управление секциями.
* Новые условия маршрутизации.
* Возможность поднять собственный VPN/proxy-сервер.
* Менеджер обновлений и установки компонентов.
* Встроенный мониторинг соединений.
* Расширенные настройки URLTest-групп.
* Автоматический выбор узла по приоритету.
* Каскадные подключения.
* Маршрутизация DNS-запросов через прокси.
* Резервные DNS-серверы.
* Отдельные DNS-серверы для выбранных доменов.
* Поддержка IPv6.
* Действие Bypass с полным обходом sing-box.
* Интеграция Zapret, Zapret2 и ByeDPI как отдельных действий секции.
* Служба полностью переписана на ucode.
* Другие исправления и улучшения.

### Что перенесено из NetShift

* **Глобальный прокси** — весь LAN-трафик через выбранный outbound: `option global_proxy '1'` на секции с действием Connection.
* **Блокировка DoH** — известные DoH-резолверы маркируются в sing-box и отбрасываются на уровне маршрутов: `option block_doh '1'` в секции `settings`.
* **Фильтры подписки по ключевым словам** — белый/чёрный список по имени узла, без учёта регистра, работает и по эмодзи: `list subscription_filter_include_keywords` / `list subscription_filter_exclude_keywords`.
* **Небезопасный TLS для подписки** — для панелей с самоподписанным или несовпадающим сертификатом: `subscription_insecure '1'` в настройках URL подписки.
* **Предпочтительный формат подписки** — `subscription_format_preference` (`auto` | `xray` | `singbox`): при `xray` первыми пробуются клиентские User-Agent, отдающие Xray JSON.
* **Автогруппировка узлов** — `subscription_group_mode` (`off` | `country` | `prefix`) + `subscription_group_prefix_len`: URLTest-группы по флагу страны или префиксу имени и авто-выбор «⚡ Самый быстрый» среди групп.
* **Списки ссылок текстом** — `selector_proxy_links_text` / `urltest_proxy_links_text`: вставка ссылок многострочным текстом, для urltest-варианта создаётся URLTest-группа с авто-выбором.
