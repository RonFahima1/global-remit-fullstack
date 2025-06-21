package main

type SessionData struct {
	UserID       string   `json:"userId"`
	Role         string   `json:"role"`
	Permissions  []string `json:"permissions"`
	LastActivity int64    `json:"lastActivity"`
}

// func main() {
// 	ctx := context.Background()
// 	fmt.Println("--- Redis Feature Demo ---")
//
// 	// 1. Cache-Aside
// 	fmt.Println("\n[Cache-Aside]")
// 	key := "client:profile:demo"
// 	val, err := cache.CacheAside(ctx, key, 5*time.Second, func() (string, error) {
// 		fmt.Println("Cache miss: fetching from DB (simulated)")
// 		return `{"id":"demo","name":"Demo Client"}` , nil
// 	})
// 	fmt.Println("CacheAside result:", val, "err:", err)
// 	val2, _ := cache.CacheAside(ctx, key, 5*time.Second, func() (string, error) {
// 		return "should not be called", nil
// 	})
// 	fmt.Println("CacheAside (should be cache hit):", val2)
//
// 	// 2. Rate Limiting
// 	fmt.Println("\n[Rate Limiting]")
// 	rKey := "rate:demo"
// 	for i := 0; i < 5; i++ {
// 		allowed, remaining, reset, err := cache.RateLimit(ctx, rKey, 3, 10*time.Second)
// 		fmt.Printf("Request %d: allowed=%v, remaining=%d, reset=%ds, err=%v\n", i+1, allowed, remaining, reset, err)
// 	}
//
// 	// 3. Session Management
// 	fmt.Println("\n[Session Management]")
// 	sess := SessionData{
// 		UserID:       "user123",
// 		Role:         "ORG_ADMIN",
// 		Permissions:  []string{"read", "write"},
// 		LastActivity: time.Now().Unix(),
// 	}
// 	sessID := "sess-demo"
// 	err = cache.SessionSet(ctx, sessID, sess, 10*time.Second)
// 	fmt.Println("SessionSet err:", err)
// 	var loaded SessionData
// 	err = cache.SessionGet(ctx, sessID, &loaded)
// 	fmt.Println("SessionGet loaded:", loaded, "err:", err)
// 	err = cache.SessionDelete(ctx, sessID)
// 	fmt.Println("SessionDelete err:", err)
//
// 	// 4. Message Queue
// 	fmt.Println("\n[Message Queue]")
// 	q := "jobs:demo"
// 	for i := 1; i <= 3; i++ {
// 		job := fmt.Sprintf("job-%d", i)
// 		err := cache.QueuePush(ctx, q, job)
// 		fmt.Println("QueuePush", job, "err:", err)
// 	}
// 	for i := 1; i <= 4; i++ {
// 		job, err := cache.QueuePop(ctx, q)
// 		fmt.Println("QueuePop", job, "err:", err)
// 	}
//
// 	_ = cache.Close()
// }
