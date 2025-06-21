# Environment Setup Guide

## Table of Contents
- [Local Development Setup](#local-development-setup)
- [Docker Setup](#docker-setup)
- [Database Setup](#database-setup)
- [Frontend Setup](#frontend-setup)
- [Testing Environment](#testing-environment)
- [Production Deployment](#production-deployment)
- [Troubleshooting](#troubleshooting)

## Local Development Setup

### 1. Clone the Repository
```bash
git clone https://github.com/your-org/global-remit.git
cd global-remit
```

### 2. Set Up Environment Variables
Create a `.env` file in the project root:
```bash
cp .env.example .env
```

### 3. Install Dependencies
```bash
# Install Go dependencies
make deps

# Install Node.js dependencies (for frontend)
cd frontend && npm install
```

### 4. Database Migration
```bash
# Run database migrations
make migrate-up

# Seed initial data
make seed
```

### 5. Start Development Servers
```bash
# Start backend server (in one terminal)
make dev

# Start frontend server (in another terminal)
cd frontend && npm run dev
```

## Docker Setup

### 1. Build and Start Containers
```bash
# Build and start all services
docker compose up -d --build

# View logs
docker compose logs -f
```

### 2. Available Services
- **API**: http://localhost:8080
- **Frontend**: http://localhost:3000
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379
- **PgAdmin**: http://localhost:5050 (username: admin@example.com, password: admin)
- **Redis Commander**: http://localhost:8081

### 3. Common Docker Commands
```bash
# Stop all containers
docker compose down

# Rebuild specific service
docker compose up -d --build <service-name>

# View running containers
docker ps

# View logs for a service
docker compose logs -f <service-name>

# Run a command in a container
docker compose exec <service-name> <command>
```

## Database Setup

### 1. PostgreSQL Configuration
```bash
# Connect to PostgreSQL
PGPASSWORD=yourpassword psql -h localhost -U postgres -d global_remit

# Common SQL Commands
\l                 # List databases
\dt                # List tables
\d+ table_name     # Describe table
\q                 # Quit
```

### 2. Database Migrations
```bash
# Create new migration
migrate create -ext sql -dir backend/db/migrations -seq migration_name

# Run migrations
make migrate-up

# Rollback last migration
make migrate-down

# View migration status
make migrate-status
```

### 3. Redis CLI
```bash
# Connect to Redis
redis-cli

# Common Commands
KEYS *             # List all keys
GET key_name       # Get value by key
DEL key_name       # Delete key
FLUSHALL           # Clear all data
```

## Frontend Setup

### 1. Development Server
```bash
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev
```

### 2. Environment Variables
Create `.env.local` in the frontend directory:
```env
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_ENV=development
```

### 3. Building for Production
```bash
# Build the application
npm run build

# Start production server
npm start
```

## Testing Environment

### 1. Unit Tests
```bash
# Run Go tests
make test

# Run frontend tests
cd frontend
npm test
```

### 2. Integration Tests
```bash
# Start test containers
docker compose -f docker-compose.test.yml up -d

# Run integration tests
make test-integration
```

### 3. E2E Testing
```bash
# Install Cypress
cd frontend
npm install cypress --save-dev

# Open Cypress test runner
npx cypress open

# Run all tests headless
npx cypress run
```

## Production Deployment

### 1. Build Production Images
```bash
docker compose -f docker-compose.prod.yml build
```

### 2. Configure Production Environment
```bash
# Create production .env file
cp .env.production .env

# Update production variables
vi .env
```

### 3. Deploy with Docker Swarm
```bash
# Initialize swarm (if not already done)
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.prod.yml global-remit

# View services
docker service ls
```

## Troubleshooting

### Common Issues

#### 1. Port Conflicts
```bash
# Find process using a port
lsof -i :3000

# Kill process
kill -9 <PID>
```

#### 2. Database Connection Issues
- Verify PostgreSQL is running
- Check connection string in `.env`
- Ensure correct credentials and database name

#### 3. Docker Issues
```bash
# Remove all containers
docker rm -f $(docker ps -aq)

# Remove unused volumes
docker volume prune

# Clear build cache
docker builder prune -a
```

#### 4. Dependency Issues
```bash
# Clean Go modules
go clean -modcache

# Reinstall Node.js modules
rm -rf node_modules package-lock.json
npm install
```

## Next Steps
1. Configure your IDE/editor with the recommended settings
2. Run the test suite to verify your setup
3. Start developing features or fixing bugs
4. Review the [API Documentation](080-API-OVERVIEW.md) for available endpoints

---

*Last updated: June 20, 2025*
