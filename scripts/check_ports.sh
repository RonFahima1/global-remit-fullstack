#!/bin/bash
# Pre-start port check for canonical project ports

PORTS=(8080 3000 5434 6380 5050 8081)

for port in "${PORTS[@]}"; do
  if lsof -i :$port; then
    echo "[ERROR] Port $port is already in use. Please free it before starting the stack."
    exit 1
  fi
done

echo "All required ports are free. Safe to start Docker Compose." 