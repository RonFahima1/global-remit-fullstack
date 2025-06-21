package domain

import (
	"encoding/json"
	"time"
)

// AuditLog represents an audit log entry.
type AuditLog struct {
	ID        string          `json:"id"`
	EventTime time.Time       `json:"event_time"`
	EventType string          `json:"event_type"`
	TableName *string         `json:"table_name,omitempty"`
	RecordID  *string         `json:"record_id,omitempty"`
	UserID    *string         `json:"user_id,omitempty"`
	UserIP    *string         `json:"user_ip,omitempty"`
	Action    string          `json:"action"`
	OldValues json.RawMessage `json:"old_values,omitempty"`
	NewValues json.RawMessage `json:"new_values,omitempty"`
}
