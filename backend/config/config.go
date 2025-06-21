package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

// Config holds the application configuration
type Config struct {
	AppEnv   string
	AppPort  string
	DBHost   string
	DBPort   string
	DBUser   string
	DBPass   string
	DBName   string
	RedisURL string
}

// Load loads configuration from .env file and environment variables
func Load() (*Config, error) {
	// Load .env file, but it's okay if it doesn't exist
	err := godotenv.Load()
	if err != nil {
		log.Println("No .env file found, using environment variables")
	}

	cfg := &Config{
		AppEnv:   getEnv("APP_ENV", "development"),
		AppPort:  getEnv("APP_PORT", "8080"),
		DBHost:   getEnv("DB_HOST", "localhost"),
		DBPort:   getEnv("DB_PORT", "5432"),
		DBUser:   getEnv("DB_USER", "postgres"),
		DBPass:   getEnv("DB_PASSWORD", "yourpassword"),
		DBName:   getEnv("DB_NAME", "global_remit"),
		RedisURL: getEnv("REDIS_URL", "redis://localhost:6379"),
	}

	return cfg, nil
}

// getEnv retrieves an environment variable or returns a fallback value
func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
