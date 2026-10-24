#!/usr/bin/env bash
# Arranca el servidor dedicado de Velvet Heist '84 sin ventana. Uso: ./servidor.sh [puerto]
cd "$(dirname "$0")"
exec ./VelvetHeist84.x86_64 --headless --server --port "${1:-7777}"
