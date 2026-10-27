# dumbproxy-quickstart

## Описание

Этот проект предназначен для быстрого запуска и настройки прокси-сервера с помощью скрипта `setup-dumbproxy.sh`.

## Быстрый старт
Для запуска используйте одну команду:

```sh
curl -sSL https://raw.githubusercontent.com/mvasilyev/dumbproxy-quickstart/main/setup-dumbproxy.sh | sudo bash
```

## Что делает скрипт

- Запрашивает у вас порт, логин и пароль для прокси.
- Устанавливает необходимые зависимости (`curl`, `jq`).
- Скачивает последнюю версию бинарника dumbproxy для Linux amd64.
- Создаёт и настраивает systemd-сервис для автоматического запуска прокси.
- Запускает сервис и выводит параметры подключения.

## Быстрый старт (Docker)
Для запуска через Docker используйте скрипт:

```sh
curl -sSL https://raw.githubusercontent.com/mvasilyev/dumbproxy-quickstart/main/setup-dumbproxy-docker.sh | sudo bash
```

## Что делает docker-скрипт

- Запрашивает у вас порт, логин и пароль для прокси.
- Проверяет наличие Docker и устанавливает его при необходимости (только для Linux).
- Скачивает официальный образ dumbproxy.
- Запускает контейнер с вашими параметрами (порт, логин, пароль).
- Контейнер автоматически перезапускается при сбоях или перезагрузке.

## Требования (Docker)

- Linux (x86_64) с поддержкой Docker Engine
- Права root (sudo)

## Примеры команд управления контейнером

- Просмотр логов: `docker logs -f dumbproxy`
- Остановить: `docker stop dumbproxy`
- Удалить: `docker rm dumbproxy`

## Несколько пользователей

Установочные скрипты настраивают одного пользователя (`-auth static://`). Чтобы раздавать отдельные учётки, переведите прокси на htpasswd-файл (`-auth basicfile://`) и управляйте пользователями скриптом `dumbproxy-user.sh`:

```sh
sudo ./dumbproxy-user.sh add alice            # добавить или сменить пароль (спросит скрыто)
sudo ./dumbproxy-user.sh issue bob            # выдать учётку со сгенерированным паролем
sudo ./dumbproxy-user.sh issue bob 'Pa55word' # выдать учётку с заданным паролем
sudo ./dumbproxy-user.sh del alice            # удалить
sudo ./dumbproxy-user.sh list                 # список
```

Файл по умолчанию — `/etc/dumbproxy/htpasswd` (переопределяется через `DP_HTPASSWD`). Режим (бинарник или Docker) определяется автоматически, его можно задать явно через `DP_MODE=native|docker`. dumbproxy перечитывает файл раз в 15 секунд (`reload=...`), поэтому изменения применяются без перезапуска.

Сначала создайте хотя бы одного пользователя (без файла прокси не стартует), затем переключите запуск:

- **systemd**: в `/etc/systemd/system/dumbproxy.service` замените строку `-auth` на
  `-auth "basicfile://?path=/etc/dumbproxy/htpasswd"`, затем `systemctl daemon-reload && systemctl restart dumbproxy`.
- **Docker**: пересоздайте контейнер с монтированием каталога:
  ```sh
  docker rm -f dumbproxy
  docker run -d --name dumbproxy --security-opt no-new-privileges --restart unless-stopped \
    -p 8080:8080 -v /etc/dumbproxy:/etc/dumbproxy:ro \
    ghcr.io/senseunit/dumbproxy:latest \
    -bind-address :8080 -auth "basicfile://?path=/etc/dumbproxy/htpasswd"
  ```

## Требования

- Linux (x86_64)
- Права root (sudo)

## Настройка

При необходимости измените переменные по умолчанию (порт, логин) при запуске скрипта — они запрашиваются интерактивно. Для изменения других параметров отредактируйте `setup-dumbproxy.sh`.

## Поддержка

Если возникли вопросы, создайте issue в репозитории.
