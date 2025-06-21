# Project Structure

## Overview

This document outlines the structure and organization of the Global Remit backend project. The project follows a clean architecture pattern with clear separation of concerns, making it maintainable, testable, and scalable.

## Root Directory Structure

```
global-remit/
├── backend/api/                    # API layer (handlers, routes, middleware)
├── backend/cmd/                    # Application entry points
├── backend/config/                 # Configuration files
├── backend/db/                     # Database migrations and seeds
├── docs/                   # Project documentation
├── backend/internal/               # Private application code
├── backend/pkg/                    # Reusable packages (can be used by external applications)
├── scripts/                # Utility scripts
├── test/                   # Additional test files
├── .env                    # Environment variables (git-ignored)
├── .gitignore             # Git ignore file
├── go.mod                  # Go module definition
├── go.sum                  # Go module checksums
├── Makefile                # Common tasks and shortcuts
└── README.md               # Project overview
```

## Detailed Structure

### `/api`

API layer components that handle HTTP requests and responses.

```
api/
├── handlers/           # Request handlers
│   ├── auth.go         # Authentication handlers
│   ├── clients.go      # Client management handlers
│   ├── accounts.go     # Account management handlers
│   └── transactions.go # Transaction handlers
├── middleware/         # HTTP middleware
│   ├── auth.go         # Authentication middleware
│   ├── logging.go      # Request logging
│   └── recovery.go     # Panic recovery
├── routes/             # Route definitions
│   ├── api.go          # Main API routes
│   └── v1/             # API version 1 routes
│       ├── clients.go
│       ├── accounts.go
│       └── transactions.go
└── docs/               # API documentation (Swagger/OpenAPI)
    └── docs.go
```

### `/cmd`

Application entry points.

```
cmd/
├── api/               # Main API server
│   └── main.go        # Entry point for the API server
└── migrate/           # Database migration tool
    └── main.go        # Entry point for migrations
```

### `/config`

Configuration management.

```
config/
├── config.go          # Configuration structure
├── defaults.go        # Default configuration values
└── load.go           # Configuration loading logic
```

### `/db`

Database migrations and seed data.

```
db/
├── migrations/        # Database migration files
│   ├── 000001_init.up.sql
│   └── 000001_init.down.sql
└── seeds/             # Seed data
    └── 0001_initial_data.sql
```

### `/internal`

Private application code that shouldn't be imported by other applications.

```
internal/
├── app/               # Application services
│   ├── auth/          # Authentication service
│   ├── client/        # Client management service
│   ├── account/       # Account management service
│   └── transaction/   # Transaction processing service
├── domain/            # Core domain models
│   ├── client.go
│   ├── account.go
│   ├── transaction.go
│   └── errors.go
├── repository/        # Data access layer
│   ├── client_repo.go
│   ├── account_repo.go
│   └── transaction_repo.go
└── pkg/               # Internal shared packages
    ├── logger/        # Logging utilities
    ├── validator/     # Custom validators
    └── util/          # Utility functions
```

### `/pkg`

Reusable packages that can be imported by other applications.

```
pkg/
├── api/               # Shared API components
│   ├── response.go    # Standardized response format
│   └── errors.go      # API error handling
├── db/                # Database utilities
│   ├── postgres.go    # PostgreSQL client
│   └── migration/     # Migration utilities
└── cache/             # Caching layer
    └── redis.go       # Redis client wrapper
```

## Code Organization Principles

### 1. Clean Architecture
- **Domain Layer**: Contains enterprise business rules and entities
- **Application Layer**: Contains application-specific business rules
- **Interface Layer**: Contains adapters that convert data between layers
- **Infrastructure Layer**: Contains technical details (DB, external services)

### 2. Dependency Rule
- Dependencies point inwards
- Inner layers define interfaces, outer layers implement them
- No dependency from inner layers to outer layers

### 3. Package Organization
- Group by feature, not by type
- Keep related code close together
- Minimize package exports (use lower-case for unexported identifiers)

## Naming Conventions

### Files
- Use `snake_case.go` for test files: `user_service_test.go`
- Use `_test` suffix for test packages: `package service_test`
- Group related files by prefix: `user_*.go`

### Packages
- Use singular nouns: `user`, not `users`
- Avoid generic names: `