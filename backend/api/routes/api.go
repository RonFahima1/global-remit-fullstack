package routes

import (
	"log/slog"
	"os"

	"backend/api/handlers"
	"backend/api/middleware"
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
	invitationHandler := handlers.NewInvitationHandler(application)
	userManagementHandler := handlers.NewUserManagementHandler(application)
	clientHandler := handlers.NewClientHandler(application)

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

			// User management routes - simplified structure
			protected.GET("/users", userManagementHandler.GetUsers)
			protected.POST("/users", userManagementHandler.CreateUser)
			protected.GET("/users/search", userManagementHandler.SearchUsers)
			protected.GET("/users/:id", userManagementHandler.GetUser)
			protected.PUT("/users/:id", userManagementHandler.UpdateUser)
			protected.PATCH("/users/:id/status", userManagementHandler.UpdateUserStatus)
			protected.POST("/users/:id/reset-password", userManagementHandler.ResetUserPassword)
			protected.DELETE("/users/:id", userManagementHandler.DeleteUser)
			protected.GET("/users/:id/permissions", userManagementHandler.GetUserPermissions)
			protected.GET("/test-users", userManagementHandler.Test)

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
		if gin.Mode() != gin.ReleaseMode {
			v1.POST("/test/seed-user", authHandler.TestSeedUser)
		}
	}

	return r
}
