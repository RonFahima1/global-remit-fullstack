package routes

import (
	"log/slog"
	"os"

	"global-remit-backend/api/handlers"
	"global-remit-backend/api/middleware"
	"global-remit-backend/internal/app"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
)

// SetupRouter configures the API routes.
func SetupRouter(db *sqlx.DB) *gin.Engine {
	r := gin.Default()

	// Configure CORS
	config := cors.DefaultConfig()
	config.AllowOrigins = []string{
		"http://localhost:3000", // Local development
		"http://frontend:3000",  // Docker network
		"http://localhost:8080", // Backend dev server
	}
	config.AllowMethods = []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"}
	config.AllowHeaders = []string{
		"Origin",
		"Content-Type",
		"Accept",
		"Authorization",
		"X-Requested-With",
		"X-CSRF-Token",
	}
	config.AllowCredentials = true

	r.Use(cors.New(config))

	// Create a logger
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	// Create an application object that holds all the services.
	application := app.New(db, logger)

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(application)
	invitationHandler := handlers.NewInvitationHandler(application)
	userManagementHandler := handlers.NewUserManagementHandler(application)
	clientHandler := handlers.NewClientHandler(application)
	healthHandler := handlers.NewHealthHandler()

	// Health check endpoint (public)
	r.GET("/api/v1/health", healthHandler.HealthCheck)

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

		// Invitation routes (public for validation and acceptance)
		invitations := v1.Group("/invitations")
		{
			invitations.GET("/validate", invitationHandler.ValidateInvitation)
			invitations.POST("/accept", invitationHandler.AcceptInvitation)
		}

		// Protected routes (require authentication)
		protected := v1.Group("/")
		protected.Use(middleware.AuthMiddleware())
		{
			// Protected auth routes
			protectedAuth := protected.Group("/auth")
			{
				protectedAuth.POST("/change-password", authHandler.ChangePassword)
			}

			// User management routes - refactored for correct Gin matching
			protected.GET("/users/self/permissions", userManagementHandler.GetSelfPermissions)
			users := protected.Group("/users")
			users.GET("/:id/permissions", userManagementHandler.GetUserPermissions)
			users.GET("/:id", userManagementHandler.GetUser)
			users.GET("", userManagementHandler.GetUsers)
			users.POST("", userManagementHandler.CreateUser)
			users.GET("/search", userManagementHandler.SearchUsers)
			users.PUT("/:id", userManagementHandler.UpdateUser)
			users.PATCH("/:id/status", userManagementHandler.UpdateUserStatus)
			users.POST("/:id/reset-password", userManagementHandler.ResetUserPassword)
			users.DELETE("/:id", userManagementHandler.DeleteUser)
			users.GET("/test-users", userManagementHandler.Test)

			// Role management routes
			protected.GET("/roles", userManagementHandler.GetRoles)

			// Invitation management (admin only)
			invitationMgmt := protected.Group("/invitations")
			{
				invitationMgmt.POST("/", invitationHandler.CreateInvitation)
				invitationMgmt.GET("/", invitationHandler.ListInvitations)
				invitationMgmt.DELETE("/:id", invitationHandler.CancelInvitation)
				invitationMgmt.POST("/:id/resend", invitationHandler.ResendInvitation)
			}

			// Client management routes
			protected.GET("/clients", clientHandler.GetClients)
			protected.POST("/clients", clientHandler.CreateClient)
		}

		// Test-only routes
		// if gin.Mode() != gin.ReleaseMode {
		// 	v1.POST("/test/seed-user", authHandler.TestSeedUser)
		// }
	}

	return r
}
