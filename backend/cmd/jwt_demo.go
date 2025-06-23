package main

import (
	"global-remit-backend/internal/utils/token"
	"context"
	"fmt"
	"os"
	"time"
)

func main() {
	os.Setenv("JWT_PRIVATE_KEY", "jwt_private.pem")
	os.Setenv("JWT_PUBLIC_KEY", "jwt_public.pem")
	fmt.Println("--- JWT Demo ---")
	if err := token.LoadKeys(); err != nil {
		fmt.Println("LoadKeys error:", err)
		return
	}
	fmt.Println("Keys loaded.")

	// Generate tokens
	access, refresh, err := token.GenerateTokenPair("user123", "admin", "branch1")
	if err != nil {
		fmt.Println("GenerateTokenPair error:", err)
		return
	}
	fmt.Println("Access token:", access)
	fmt.Println("Refresh token:", refresh)

	// Validate access token
	claims, err := token.ValidateToken(access)
	fmt.Println("ValidateToken claims:", claims, "err:", err)

	// Revoke access token
	err = token.RevokeToken(context.Background(), claims.ID, time.Now().Add(15*time.Minute))
	fmt.Println("RevokeToken err:", err)

	// Validate again (should be revoked)
	_, err = token.ValidateToken(access)
	fmt.Println("ValidateToken after revoke err:", err)
}
