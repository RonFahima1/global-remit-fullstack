# Canonical Port Assignments

> **Policy:** Never change port numbers in code or config. All code must reference these canonical ports via environment variables. If a port is unavailable, fail with a clear error. See `scripts/check_ports.sh` for port conflict checks.

| Service         | Port | Environment Variable         |
|-----------------|------|-----------------------------|
| Frontend (UI)   | 3000 | NEXT_PUBLIC_UI_URL          |
| Backend (API)   | 8080 | APP_PORT                    |
| Postgres DB     | 5432 | DB_PORT                     |
| Test DB         | 5434 | DB_PORT (in test context)    |
| Redis           | 6379 | REDIS_URL / REDIS_PORT      |

## Usage
- All code must use the environment variable, never a hardcoded port.
- If you need to change a port, update this file and all relevant environment variables, never the code.
- Run `scripts/check_ports.sh` before starting services to check for conflicts.

---

**Example .env:**
```
NEXT_PUBLIC_UI_URL=http://localhost:3000
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080/api
APP_PORT=8080
DB_PORT=5432
REDIS_URL=redis://localhost:6379
```

## Enforcement Policy
- **Never change port numbers in code, Docker Compose, or .env files.**
- All services must use the ports above.
- If a port is in use, stop the conflicting process before starting the stack.
- Use the provided pre-start script to check for port conflicts.

## Pre-Start Port Check Script

Add this to your workflow before running `docker-compose up`:

```sh
for port in 8080 3000 5434 6380 5050 8081; do
  if lsof -i :$port; then
    echo "Port $port is already in use. Please free it before starting the stack."
    exit 1
  fi
done
```

## Note
- Never run dev servers on these ports outside Docker Compose.
- Document any changes to this policy in this file and in `CONTRIBUTING.md`. 