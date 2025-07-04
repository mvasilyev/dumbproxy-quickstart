#!/usr/bin/env bash
set -euo pipefail

# 1. Ввод параметров (читает из терминала)
read -rp "На каком порту запускаем dumbproxy? [8080]: " PORT < /dev/tty
PORT=${PORT:-8080}

read -rp "Введите логин для прокси [admin]: " DP_USER < /dev/tty
DP_USER=${DP_USER:-admin}

# Скрытый ввод пароля
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

# 2. Установка зависимостей
apt-get update
apt-get install -y curl jq

# 3. Скачиваем последний релиз
echo "Определяем последнюю версию dumbproxy..."
LATEST_JSON=$(curl -sSL https://api.github.com/repos/SenseUnit/dumbproxy/releases/latest)
DOWNLOAD_URL=$(echo "$LATEST_JSON" | jq -r '.assets[] | select(.name|test("linux_amd64$")) .browser_download_url')
if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Не удалось найти бинарник для linux_amd64." >&2
  exit 1
fi

echo "Скачиваем $DOWNLOAD_URL …"
curl -sSL "$DOWNLOAD_URL" -o /usr/local/bin/dumbproxy
chmod +x /usr/local/bin/dumbproxy

# 4. Генерируем systemd-сервис
SERVICE=/etc/systemd/system/dumbproxy.service
echo "Создаём systemd-сервис в $SERVICE …"
cat > "$SERVICE" <<EOF
[Unit]
Description=dumbproxy — простой скриптуемый forward proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/dumbproxy \\
    -bind-address :${PORT} \\
    -auth "static://?username=${DP_USER}&password=${DP_PASS}"
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 5. Включаем и запускаем
systemctl daemon-reload
systemctl enable --now dumbproxy

echo -e "\nДлинк: 0.0.0.0:${PORT}\nЛогин: ${DP_USER}\nПароль: (скрыт)"
echo "Логи: journalctl -u dumbproxy -f"