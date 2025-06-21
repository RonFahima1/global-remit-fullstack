package db

import (
	"database/sql"
	"log"

	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
)

type TestUser struct {
	FirstName string
	LastName  string
	Email     string
	Password  string
	Role      string
	Status    string
}

func SeedTestUsers(db *sql.DB) {
	testUsers := []TestUser{
		{
			FirstName: "Org",
			LastName:  "Admin",
			Email:     "orgadmin@example.com",
			Password:  "password",
			Role:      "ORG_ADMIN",
			Status:    "ACTIVE",
		},
		{
			FirstName: "Agent",
			LastName:  "Admin",
			Email:     "agentadmin@example.com",
			Password:  "password",
			Role:      "AGENT_ADMIN",
			Status:    "ACTIVE",
		},
	}

	for _, u := range testUsers {
		var roleID string
		err := db.QueryRow("INSERT INTO auth.roles (name) VALUES ($1) ON CONFLICT (name) DO NOTHING RETURNING id", u.Role).Scan(&roleID)
		if err != nil {
			// It might fail if role exists and RETURNING id doesn't work on conflict, so we query it.
			err = db.QueryRow("SELECT id FROM auth.roles WHERE name=$1", u.Role).Scan(&roleID)
			if err != nil {
				log.Fatalf("failed to get role %s: %v", u.Role, err)
			}
		}

		passwordHash, err := bcrypt.GenerateFromPassword([]byte(u.Password), bcrypt.DefaultCost)
		if err != nil {
			log.Fatalf("failed to hash password for %s: %v", u.Email, err)
		}

		var userID string
		err = db.QueryRow(`
			INSERT INTO auth.users (username, email, email_verified, password_hash, status, first_name, last_name) 
			VALUES ($1, $2, true, $3, $4, $5, $6) 
			ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash
			RETURNING id`,
			u.Email, u.Email, string(passwordHash), u.Status, u.FirstName, u.LastName).Scan(&userID)
		if err != nil {
			log.Fatalf("failed to insert user %s: %v", u.Email, err)
		}

		_, err = db.Exec(`
			INSERT INTO auth.user_roles (user_id, role_id) VALUES ($1, $2)
			ON CONFLICT (user_id, role_id) DO NOTHING`, userID, roleID)
		if err != nil {
			log.Fatalf("failed to assign role %s to user %s: %v", u.Role, u.Email, err)
		}
		log.Printf("Seeded user: %s (%s)", u.Email, u.Role)
	}
}
