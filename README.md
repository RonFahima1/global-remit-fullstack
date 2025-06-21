# Global Remit Fullstack App

## Quick Start (Docker Compose)

1. **Build and start all services:**
   ```sh
   docker-compose up --build
   ```
   - This will start:
     - Postgres (with persistent volume)
     - Redis
     - Go backend API
     - Next.js frontend (on http://localhost:3000)
     - PgAdmin (on http://localhost:5050)
     - Redis Commander (on http://localhost:8081)

2. **Access the app:**
   - Frontend: [http://localhost:3000](http://localhost:3000)
   - Backend API: [http://localhost:8080/api/v1](http://localhost:8080/api/v1)
   - PgAdmin: [http://localhost:5050](http://localhost:5050) (user: admin@example.com, pass: admin)
   - Redis Commander: [http://localhost:8081](http://localhost:8081)

3. **Restore the database (if needed):**
   - To restore the saved DB state:
     ```sh
     docker-compose exec postgres psql -U postgres -d global_remit < /db-backup-global_remit.sql
     ```
   - Or use PgAdmin to import `db-backup-global_remit.sql`.

## Project Structure

- `backend/` - Go API
- `Frontend/` - Next.js app (Dockerized)
- `docker-compose.yml` - All services
- `db-backup-global_remit.sql` - Postgres DB backup

## Development
- You can run any service individually, but Docker Compose is recommended for consistency.
- To stop all services:
  ```sh
  docker-compose down
  ```

---

**Everything is now ready for you to continue development or deploy anywhere Docker is supported!** 