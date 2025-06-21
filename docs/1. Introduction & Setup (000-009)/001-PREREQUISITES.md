# Prerequisites

## System Requirements

### Development Environment
- **Operating System**: macOS 12+ / Ubuntu 20.04+ / Windows 10/11 with WSL2
- **CPU**: 4 cores (8+ recommended for better performance)
- **RAM**: 16GB (32GB recommended for running multiple services)
- **Disk Space**: 20GB free space (50GB recommended with Docker images and dependencies)
- **Display**: 1440x900 minimum resolution (1920x1080 recommended)

### Production Environment
- **CPU**: 4+ cores
- **RAM**: 8GB minimum (16GB recommended)
- **Storage**: 100GB+ (SSD recommended)
- **Network**: Stable internet connection with static IP

## Development Tools

### Version Control
- **Git**: 2.30+
  ```bash
  # Verify installation
  git --version
  
  # Recommended global configuration
  git config --global user.name "Your Name"
  git config --global user.email "your.email@example.com"
  git config --global pull.rebase true
  git config --global init.defaultBranch main
  ```

### Go Development
- **Go**: 1.21+
  ```bash
  # Install on macOS
  brew install go
  
  # Install on Ubuntu
  sudo apt update
  sudo apt install golang-go
  
  # Verify installation
  go version
  
  # Environment setup (add to ~/.zshrc or ~/.bashrc)
  export GOPATH=$HOME/go
  export PATH=$PATH:$GOPATH/bin
  export PATH=$PATH:$(go env GOPATH)/bin
  export GO111MODULE=on
  ```

### Node.js & NPM
- **Node.js**: 18+ (LTS)
- **npm**: 9+ or **Yarn**: 1.22+
  ```bash
  # Install using nvm (recommended)
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
  
  # Install LTS version
  nvm install --lts
  nvm use --lts
  
  # Verify installation
  node --version
  npm --version
  ```

## Containerization

### Docker & Docker Compose
- **Docker**: 20.10+
- **Docker Compose**: 2.10+
  ```bash
  # Install Docker Desktop (macOS/Windows) or Docker Engine (Linux)
  # macOS: https://docs.docker.com/desktop/install/mac-install/
  # Windows: https://docs.docker.com/desktop/install/windows-install/
  # Ubuntu: https://docs.docker.com/engine/install/ubuntu/
  
  # Verify installation
  docker --version
  docker compose version
  
  # Start Docker service (Linux)
  sudo systemctl enable docker
  sudo systemctl start docker
  
  # Add user to docker group (Linux)
  sudo usermod -aG docker $USER
  newgrp docker
  ```

## Database

### PostgreSQL
- **PostgreSQL**: 14+
  ```bash
  # Install using Docker (recommended for development)
  docker run --name postgres \
    -e POSTGRES_PASSWORD=yourpassword \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_DB=global_remit \
    -p 5432:5432 \
    -d postgres:14-alpine
  
  # Or install natively
  # macOS: brew install postgresql@14
  # Ubuntu: sudo apt install postgresql-14
  
  # Verify connection
  psql -h localhost -U postgres -c "SELECT version();"
  ```

### Redis
- **Redis**: 7.0+
  ```bash
  # Install using Docker (recommended for development)
  docker run --name redis -p 6379:6379 -d redis:7-alpine
  
  # Or install natively
  # macOS: brew install redis
  # Ubuntu: sudo apt install redis-server
  
  # Verify connection
  redis-cli ping
  ```

## Development Tools

### Code Editor
- **VS Code** (recommended) or any Go/TypeScript compatible IDE
  - VS Code Extensions:
    - Go (Go Team at Google)
    - ESLint
    - Prettier
    - Docker
    - GitLens
    - YAML
    - Markdown All in One
    - REST Client
    - Database Client

### Go Tools
```bash
# Install essential Go tools
go install golang.org/x/tools/cmd/goimports@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/vektra/mockery/v2@latest
go install github.com/cweill/gotests/...@latest
go install github.com/swaggo/swag/cmd/swag@latest  # For API documentation

# Verify installations
goimports -h
golangci-lint --version
mockery --version
gotests -h
swag -v
```

### Node.js Tools
```bash
# Install global npm packages
npm install -g typescript ts-node nodemon jest
npm install -g @mockoon/cli  # For API mocking

# Verify installations
tsc --version
ts-node --version
nodemon --version
jest --version
mockoon-cli --version
```

## API Clients

### HTTP Clients
- **Postman** or **Insomnia** for API testing
- **curl** (command line)
  ```bash
  # Install curl if not available
  # macOS: brew install curl
  # Ubuntu: sudo apt install curl
  
  # Verify installation
  curl --version
  ```

### gRPC Tools
```bash
# Install protoc and Go plugins
# macOS
brew install protobuf protoc-gen-go protoc-gen-go-grpc

# Ubuntu
sudo apt install -y protobuf-compiler
GO111MODULE=on go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
GO111MODULE=on go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

# Verify installations
protoc --version
protoc-gen-go --version
protoc-gen-go-grpc --version
```

## Version Control

### Git Hooks
```bash
# Install pre-commit hooks
# In project root
cp .githooks/* .git/hooks/
chmod +x .git/hooks/*
```

### Git Configuration
```bash
# Recommended Git settings
git config --global pull.rebase true
git config --global rebase.autoStash true
git config --global commit.gpgsign true
git config --global core.editor "code --wait"
git config --global core.autocrlf input  # For macOS/Linux
# git config --global core.autocrlf true  # For Windows
```

## Environment Setup

### Environment Variables
Create a `.env` file in the project root with the following variables:
```env
# Application
APP_ENV=development
APP_NAME=global-remit
APP_PORT=8080
APP_SECRET=your-secret-key-here
APP_URL=http://localhost:8080

# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=yourpassword
DB_NAME=global_remit
DB_SSLMODE=disable
DB_MAX_OPEN_CONNS=25
DB_MAX_IDLE_CONNS=5
DB_CONN_MAX_LIFETIME=5m

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0
REDIS_POOL_SIZE=10

# JWT
JWT_SECRET=your-jwt-secret-key
JWT_ACCESS_TOKEN_EXPIRY=15m
JWT_REFRESH_TOKEN_EXPIRY=24h

# Email (SMTP)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=user@example.com
SMTP_PASSWORD=your-smtp-password
SMTP_FROM=support@globalremit.com
SMTP_TLS=true

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
CORS_ALLOWED_METHODS=GET,POST,PUT,PATCH,DELETE,OPTIONS
CORS_ALLOWED_HEADERS=Content-Type,Authorization,X-Requested-With

# Logging
LOG_LEVEL=debug
LOG_FORMAT=json
LOG_FILE=logs/app.log

# Feature Flags
FEATURE_MAINTENANCE_MODE=false
FEATURE_NEW_UI=false
```

## Verification

### Verify All Installations
```bash
# Check Go installation
go version

# Check Node.js and npm
node --version
npm --version

# Check Docker
docker --version
docker compose version

# Check PostgreSQL
psql --version

# Check Redis
redis-cli --version

# Check Git
git --version
```

## Troubleshooting

### Common Issues
1. **Port Conflicts**:
   - Check if ports 3000, 5432, 6379, 8080 are in use
   ```bash
   # Linux/macOS
   lsof -i :3000
   
   # Windows
   netstat -ano | findstr :3000
   ```

2. **Docker Permission Issues**:
   ```bash
   # Add user to docker group
   sudo usermod -aG docker $USER
   newgrp docker
   ```

3. **Go Module Issues**:
   ```bash
   # Clean module cache
   go clean -modcache
   
   # Tidy modules
   go mod tidy
   ```

## Next Steps
1. Set up your development environment using the instructions in `002-ENVIRONMENT-SETUP.md`
2. Configure your IDE/editor with the recommended extensions
3. Start the development services using Docker Compose
4. Run the application in development mode

---

*Last updated: June 20, 2025*
