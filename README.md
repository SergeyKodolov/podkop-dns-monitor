# Podkop DNS Monitor

Автоматический мониторинг и переключение DNS-серверов для OpenWRT/ImmortalWRT с уведомлениями в Telegram.

## 📋 Описание

Podkop DNS Monitor — это утилита для роутеров на базе OpenWRT/ImmortalWRT, которая автоматически мониторит доступность основного DNS-сервера и переключается на резервный в случае недоступности. Поддерживает уведомления в Telegram и детальное логирование.

### Основные возможности

- 🔄 Автоматическое переключение между основным и резервным DNS
- 📡 Мониторинг каждые 1-5 минут (настраивается через cron)
- 📱 Уведомления в Telegram о переключениях
- 📝 Подробное логирование всех операций
- 🔧 Простая установка одной командой
- ⚙️ Гибкая настройка параметров

### Как это работает

1. **Основной режим**: Использует указанный DNS-сервер через UDP на определенном интерфейсе
2. **Резервный режим**: При недоступности основного DNS переключается на DoH (DNS over HTTPS)
3. **Автовосстановление**: Автоматически возвращается к основному DNS при восстановлении доступности

## 🛠️ Требования

### Системные требования
- OpenWRT или ImmortalWRT
- Права root для установки
- Интернет-соединение для загрузки скрипта

### Необходимые пакеты
- `uci` (системная утилита OpenWRT)
- `nslookup` (для проверки DNS)
- `curl` (для уведомлений Telegram)
- `crontab` (для автоматического запуска)
- `logger` (для логирования)
- `podkop` (основной сервис)

### Telegram (опционально)
- Bot Token от @BotFather
- Chat ID от @userinfobot

## 🚀 Установка

### Быстрая установка

```bash
# Скачайте и запустите установочный скрипт
sh <(wget -O - https://raw.githubusercontent.com/SergeyKodolov/podkop-dns-monitor/main/install.sh)
```

### Пошаговая установка

1. **Скачайте установочный скрипт**
   ```bash
   wget https://raw.githubusercontent.com/SergeyKodolov/podkop-dns-monitor/main/install.sh
   chmod +x install.sh
   ```

2. **Запустите установку**
   ```bash
   ./install.sh
   ```

### Процесс установки

Во время установки вам будет предложено ввести:

1. **Telegram Bot Token** - получите от @BotFather в Telegram
2. **Telegram Chat ID** - получите от @userinfobot в Telegram  
3. **Primary DNS Server IP** - IP-адрес основного DNS-сервера
4. **DNS Interface** - сетевой интерфейс для DNS (например, `wan`)
5. **Test Domain** - домен для проверки DNS (по умолчанию: `google.com`)
6. **Backup DNS Server** - резервный DNS (по умолчанию: `dns.adguard-dns.com`)

### Пример конфигурации

```
Primary DNS: 192.168.1.10
DNS Interface: wan
Test Domain: google.com
Backup DNS: dns.adguard-dns.com
```

## 📱 Настройка Telegram уведомлений

### 1. Создание бота

1. Найдите @BotFather в Telegram
2. Отправьте команду `/newbot`
3. Следуйте инструкциям для создания бота
4. Сохраните полученный Bot Token

### 2. Получение Chat ID

1. Найдите @userinfobot в Telegram
2. Отправьте команду `/start`
3. Скопируйте ваш Chat ID из ответа

### 3. Проверка настроек

После установки отправьте тестовое сообщение:
```bash
/usr/bin/podkop_dns_monitor
```

## 🔧 Управление и мониторинг

### Основные команды

```bash
# Запуск проверки вручную
/usr/bin/podkop_dns_monitor

# Просмотр логов в режиме реального времени
logread -f | grep podkop-dns-monitor

# Проверка cron задач
crontab -l

# Просмотр текущей конфигурации podkop
uci show podkop
```

### Просмотр логов

```bash
# Все логи мониторинга
logread | grep podkop-dns-monitor

# Только ошибки
logread | grep podkop-dns-monitor | grep err

# Логи установки
logread | grep podkop-dns-monitor-install
```

### Статусы в логах

- `info` - обычные операции (переключения, перезапуски)
- `debug` - детальная информация о проверках
- `warn` - предупреждения (недоступность DNS)
- `err` - ошибки (проблемы с конфигурацией или службой)

## ⚙️ Настройка частоты проверок

По умолчанию проверки выполняются каждую минуту. Для изменения частоты:

```bash
# Редактировать cron
crontab -e

# Примеры частоты:
# Каждую минуту:     * * * * * /usr/bin/podkop_dns_monitor
# Каждые 5 минут:    */5 * * * * /usr/bin/podkop_dns_monitor
# Каждые 10 минут:   */10 * * * * /usr/bin/podkop_dns_monitor
```

## 🔄 Принцип работы

### Режимы работы

**Основной DNS доступен:**
- Тип: UDP
- Сервер: Указанный primary DNS
- Интерфейс: Привязка к указанному интерфейсу

**Основной DNS недоступен:**
- Тип: DoH (DNS over HTTPS)
- Сервер: Резервный DNS
- Интерфейс: Без привязки

### Алгоритм работы

1. Проверка доступности основного DNS через `nslookup`
2. Сравнение с текущей конфигурацией
3. При необходимости — переключение конфигурации
4. Перезапуск службы podkop
5. Отправка уведомления в Telegram
6. Логирование результатов

## 🔧 Ручная настройка

### Изменение параметров

Отредактируйте файл `/usr/bin/podkop_dns_monitor`:

```bash
vi /usr/bin/podkop_dns_monitor
```

Найдите и измените нужные параметры:
```bash
PRIMARY_DNS_SERVER="192.168.1.10"
BACKUP_DNS_SERVER="dns.adguard-dns.com"
DNS_INTERFACE="wan"
TEST_DOMAIN="google.com"
```

### Смена Telegram настроек

```bash
# Отредактируйте токен и chat ID
sed -i 's/TELEGRAM_BOT_TOKEN=".*"/TELEGRAM_BOT_TOKEN="NEW_TOKEN"/' /usr/bin/podkop_dns_monitor
sed -i 's/TELEGRAM_CHAT_ID=".*"/TELEGRAM_CHAT_ID="NEW_CHAT_ID"/' /usr/bin/podkop_dns_monitor
```

## 🗑️ Удаление

### Полное удаление

```bash
# Удалить cron задачу
crontab -l | grep -v podkop_dns_monitor | crontab -

# Удалить скрипт
rm -f /usr/bin/podkop_dns_monitor

# Удалить резервные копии (опционально)
rm -f /usr/bin/podkop_dns_monitor.backup.*
```

### Временное отключение

```bash
# Отключить cron задачу
crontab -l | sed 's|^|#|' | grep podkop_dns_monitor | crontab -
```