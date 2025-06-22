package main

import (
	"flag"
	"log"

	"backend/api/routes"
	"backend/config"
	"backend/internal/utils/token"
	"backend/pkg/db"
)

func main() {
	var seed bool
	flag.BoolVar(&seed, "seed", false, "seed the database with test data")
	flag.Parse()

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	if err := token.LoadKeys(); err != nil {
		log.Fatalf("failed to load jwt keys: %v", err)
	}

	database, err := db.Connect(cfg)
	if err != nil {
		log.Fatalf("failed to connect to db: %v", err)
	}

	if seed {
		log.Println("Seeding database...")
		db.SeedTestUsers(database.DB)
	}

	r := routes.SetupRouter(database)

	// Debug: Print all registered routes
	for _, ri := range r.Routes() {
		log.Printf("Registered route: %s %s", ri.Method, ri.Path)
	}

	if err := r.Run(":" + cfg.AppPort); err != nil {
		log.Fatalf("failed to run server: %v", err)
	}
}
