package main

import (
	"fmt"

	"golang.org/x/crypto/bcrypt"
)

func main() {
	hash := "$2a$10$WqTSy/ljsT.I.VLTnR9IS.hlnsk8K0NI7MSExICTlJamnG7HFEeQi"
	password := "Password123"
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	if err != nil {
		fmt.Println("NO MATCH:", err)
	} else {
		fmt.Println("MATCH!")
	}
}
