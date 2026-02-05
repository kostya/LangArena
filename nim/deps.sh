#!/bin/bash
# Отключаем проверку безопасности Git для этого репозитория
git config --global --add safe.directory /src
git config --global --add safe.directory /src/nim

# Устанавливаем пакеты
nimble refresh
nimble install -y integers jsony

