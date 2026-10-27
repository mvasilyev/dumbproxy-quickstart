#!/usr/bin/env bash
set -euo pipefail

# Управление пользователями dumbproxy (htpasswd-файл для -auth basicfile://)
#
#   dumbproxy-user.sh add <логин>              — добавить или сменить пароль (ввод скрыто)
#   dumbproxy-user.sh issue <логин> [пароль]   — выдать учётку: пароль из аргумента или
#                                                сгенерированный, выводится на экран
#   dumbproxy-user.sh del <логин>              — удалить пользователя
#   dumbproxy-user.sh list                     — показать пользователей
#
# Переменные окружения:
#   DP_HTPASSWD — путь к файлу [/etc/dumbproxy/htpasswd]
#   DP_MODE     — native | docker [определяется автоматически]

HTPASSWD=${DP_HTPASSWD:-/etc/dumbproxy/htpasswd}
IMAGE="ghcr.io/senseunit/dumbproxy:latest"
CONTAINER_NAME="dumbproxy"
# UID, под которым dumbproxy работает в официальном образе
CONTAINER_UID="9999:9999"

usage() {
  echo "Использование: $0 {add|issue|del|list} [логин] [пароль]" >&2
  exit 1
}

detect_mode() {
  if [[ -n "${DP_MODE:-}" ]]; then
    echo "$DP_MODE"
  elif command -v docker &>/dev/null && docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo docker
  elif command -v dumbproxy &>/dev/null; then
    echo native
  else
    echo "Не найден ни бинарник dumbproxy, ни контейнер $CONTAINER_NAME. Укажите DP_MODE=native|docker." >&2
    exit 1
  fi
}

check_username() {
  if [[ ! "$1" =~ ^[A-Za-z0-9._@-]+$ ]]; then
    echo "Недопустимый логин: разрешены латиница, цифры и символы . _ @ -" >&2
    exit 1
  fi
}

user_exists() {
  [[ -f "$HTPASSWD" ]] && grep -q "^$1:" "$HTPASSWD"
}

# Удаляем строку, сохраняя inode и права файла
remove_user() {
  local tmp
  tmp=$(mktemp)
  grep -v "^$1:" "$HTPASSWD" > "$tmp" || true
  cat "$tmp" > "$HTPASSWD"
  rm -f "$tmp"
}

# dumbproxy -passwd дописывает строку в конец файла.
# Без пароля в аргументах dumbproxy сам спрашивает его скрыто.
append_user() {
  local dir
  dir=$(dirname "$HTPASSWD")
  mkdir -p "$dir"
  if [[ "$MODE" == "docker" ]]; then
    if [[ $# -eq 2 ]]; then
      docker run --rm --user 0:0 -v "$dir:$dir" "$IMAGE" -passwd "$HTPASSWD" "$1" "$2"
    else
      docker run --rm -it --user 0:0 -v "$dir:$dir" "$IMAGE" -passwd "$HTPASSWD" "$1" < /dev/tty
    fi
    chown "$CONTAINER_UID" "$HTPASSWD"
  else
    if [[ $# -eq 2 ]]; then
      dumbproxy -passwd "$HTPASSWD" "$1" "$2"
    else
      dumbproxy -passwd "$HTPASSWD" "$1" < /dev/tty
    fi
  fi
}

# Добавляет пользователя или заменяет пароль существующему
set_user() {
  local backup
  if ! user_exists "$1"; then
    append_user "$@"
    return
  fi
  echo "Пользователь $1 уже есть — пароль будет заменён."
  # Бэкап, чтобы при ошибке ввода не потерять старую запись
  backup=$(mktemp)
  cp -p "$HTPASSWD" "$backup"
  remove_user "$1"
  if ! append_user "$@"; then
    cat "$backup" > "$HTPASSWD"
    rm -f "$backup"
    echo "Не удалось задать пароль, старая запись восстановлена." >&2
    exit 1
  fi
  rm -f "$backup"
}

generate_password() {
  local pw
  pw=$(LC_ALL=C tr -dc 'A-Za-z0-9' < <(head -c 512 /dev/urandom))
  echo "${pw:0:20}"
}

if [[ $EUID -ne 0 ]]; then
  echo "Запустите скрипт от root (sudo)." >&2
  exit 1
fi

CMD=${1:-}
case "$CMD" in
  add)
    [[ $# -eq 2 ]] || usage
    check_username "$2"
    MODE=$(detect_mode)
    set_user "$2"
    echo "Готово: $2"
    ;;
  issue)
    [[ $# -eq 2 || $# -eq 3 ]] || usage
    check_username "$2"
    MODE=$(detect_mode)
    PASSWORD=${3:-$(generate_password)}
    set_user "$2" "$PASSWORD"
    echo
    echo "Логин:  $2"
    echo "Пароль: $PASSWORD"
    ;;
  del)
    [[ $# -eq 2 ]] || usage
    check_username "$2"
    if ! user_exists "$2"; then
      echo "Пользователь $2 не найден." >&2
      exit 1
    fi
    remove_user "$2"
    echo "Удалён: $2"
    ;;
  list)
    [[ -f "$HTPASSWD" ]] || { echo "Файл $HTPASSWD ещё не создан."; exit 0; }
    cut -d: -f1 "$HTPASSWD"
    ;;
  *)
    usage
    ;;
esac
