package routes

import (
	"log/slog"
	"os"

	"backend/api/handlers"
	"backend/internal/app"

	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
)

// SetupRouter configures the API routes.
func SetupRouter(db *sqlx.DB) *gin.Engine {
	r := gin.Default()

	// Create a logger
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	// Create an application object that holds all the services.
	application := app.New(db, logger)

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(application)

	// Group routes under /api/v1
	v1 := r.Group("/api/v1")
	{
		// Auth routes (public)
		auth := v1.Group("/auth")
		{
			auth.POST("/register", authHandler.RegisterUser)
			auth.POST("/login", authHandler.Login)
			auth.POST("/refresh", authHandler.Refresh)
			auth.POST("/logout", authHandler.Logout)
			auth.GET("/me", authHandler.Me)
		}

		// Test-only routes
		if gin.Mode() != gin.ReleaseMode {
			v1.POST("/test/seed-user", authHandler.TestSeedUser)
		}
	}

	return r
}
