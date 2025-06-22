package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"backend/config"
	"backend/internal/repository"
	"backend/pkg/db"
)

func main() {
	// Set environment variables
	os.Setenv("DB_HOST", "localhost")
	os.Setenv("DB_PORT", os.Getenv("DB_PORT")) // Never change port number here. Use canonical port from env/config.
	os.Setenv("DB_USER", "postgres")
	os.Setenv("DB_PASSWORD", "postgres")
	os.Setenv("DB_NAME", "global_remit")

	// Load config
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Connect to database
	database, err := db.Connect(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()

	fmt.Println("✅ Database connected successfully")

	// Test user retrieval
	authRepo := repository.NewAuthRepository(database)

	// Test getting user by email
	user, err := authRepo.GetUserByEmail(context.Background(), "admin@example.com")
	if err != nil {
		log.Fatalf("Failed to get user: %v", err)
	}

	fmt.Printf("✅ User found: %s (ID: %s, Status: %s, Role: %s)\n",
		user.Email, user.ID, user.Status, user.Role)

	// Test authentication
	authenticatedUser, err := authRepo.AuthenticateUser(context.Background(), "admin@example.com", "Password123!")
	if err != nil {
		log.Fatalf("Authentication failed: %v", err)
	}

	fmt.Printf("✅ Authentication successful: %s\n", authenticatedUser.Email)

	// Test permissions
	permissions, err := authRepo.GetUserPermissions(context.Background(), authenticatedUser.ID.String())
	if err != nil {
		log.Fatalf("Failed to get permissions: %v", err)
	}

	fmt.Printf("✅ User permissions: %v\n", permissions)
}
