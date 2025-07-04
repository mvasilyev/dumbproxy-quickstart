#!/usr/bin/env bash
set -euo pipefail

# 1. Prompt for parameters
read -rp "На каком порту запускаем dumbproxy? [8080]: " PORT < /dev/tty
PORT=${PORT:-8080}

read -rp "Введите логин для прокси [admin]: " DP_USER < /dev/tty
DP_USER=${DP_USER:-admin}

# Hidden password input
while true; do
  read -rsp "Введите пароль для proxy (скрыто): " DP_PASS < /dev/tty
  echo
  read -rsp "Подтвердите пароль: " DP_PASS2 < /dev/tty
  echo
  if [[ "$DP_PASS" == "$DP_PASS2" ]]; then
    break
  else
    echo "Пароли не совпали, попробуйте снова."
  fi
done

# 2. Check for Docker, install if missing (server-friendly)
if ! command -v docker &>/dev/null; then
  echo "Docker не установлен. Пытаемся установить Docker Engine..."
  OS_TYPE=$(uname -s)
  if [[ "$OS_TYPE" == "Linux" ]]; then
    # Install Docker Engine using official convenience script
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo "Docker Engine установлен."
  elif [[ "$OS_TYPE" == "Darwin" ]]; then
    echo "На macOS сервере Docker Engine не поддерживается напрямую. Пожалуйста, установите Docker Desktop вручную: https://docs.docker.com/desktop/install/mac/"
    exit 1
  else
    echo "Пожалуйста, установите Docker вручную для вашей ОС: https://docs.docker.com/get-docker/"
    exit 1
  fi
fi

# 3. Pull latest dumbproxy image (or build if not available)
IMAGE="ghcr.io/senseunit/dumbproxy:latest"
echo "Пробуем скачать образ $IMAGE ..."
docker pull $IMAGE || {
  echo "Не удалось скачать образ. Попробуйте позже или соберите вручную." >&2
  exit 1
}

# 4. Run dumbproxy container
CONTAINER_NAME="dumbproxy"

# Remove old container if exists
if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
  echo "Удаляем старый контейнер $CONTAINER_NAME ..."
  docker rm -f $CONTAINER_NAME
fi

echo "Запускаем dumbproxy в контейнере ..."
docker run -d \
  --name $CONTAINER_NAME \
  --security-opt no-new-privileges \
  --restart unless-stopped \
  -p ${PORT}:${PORT} \
  $IMAGE \
  -bind-address :${PORT} \
  -auth "static://?username=${DP_USER}&password=${DP_PASS}"

# 5. Output info
echo -e "\nДлинк: 0.0.0.0:${PORT}\nЛогин: ${DP_USER}\nПароль: (скрыт)"
echo "Логи: docker logs -f $CONTAINER_NAME"
echo "Остановить: docker stop $CONTAINER_NAME"
echo "Удалить: docker rm $CONTAINER_NAME"
