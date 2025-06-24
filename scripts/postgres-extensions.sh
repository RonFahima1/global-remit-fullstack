#!/bin/bash

# PostgreSQL Extensions Installation and Configuration Script
# This script installs and configures all required PostgreSQL extensions

set -e

echo "Installing PostgreSQL extensions..."

# Wait for PostgreSQL to be ready
until pg_isready -U postgres -d global_remit; do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 2
done

# Connect to PostgreSQL and install extensions
psql -U postgres -d global_remit << 'EOF'

-- Install required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
-- Note: pg_cron is not available in pgvector image, we'll use alternative scheduling
-- CREATE EXTENSION IF NOT EXISTS "pg_cron";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create schemas if they don't exist
CREATE SCHEMA IF NOT EXISTS crypto;
CREATE SCHEMA IF NOT EXISTS ai;
CREATE SCHEMA IF NOT EXISTS maintenance;

-- Grant permissions
GRANT USAGE ON SCHEMA crypto TO postgres;
GRANT USAGE ON SCHEMA ai TO postgres;
GRANT USAGE ON SCHEMA maintenance TO postgres;

-- Configure vector extension
ALTER SYSTEM SET vector.enable_cosine_distance = on;
ALTER SYSTEM SET vector.enable_l2_distance = on;
ALTER SYSTEM SET vector.enable_inner_product = on;

-- Configure pg_stat_statements
ALTER SYSTEM SET pg_stat_statements.track = 'all';
ALTER SYSTEM SET pg_stat_statements.max = 10000;

-- Reload configuration
SELECT pg_reload_conf();

-- Verify extensions are installed
SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'pgcrypto', 'pg_stat_statements');

-- Create alternative scheduling mechanism since pg_cron is not available
CREATE OR REPLACE FUNCTION maintenance.schedule_task(
    task_name TEXT,
    task_function TEXT,
    interval_seconds INTEGER DEFAULT 3600
)
RETURNS VOID AS $$
BEGIN
    -- Store task in a configuration table for external scheduling
    INSERT INTO config.scheduled_tasks (task_name, task_function, interval_seconds, last_run, next_run)
    VALUES (task_name, task_function, interval_seconds, NULL, NOW() + (interval_seconds || ' seconds')::INTERVAL)
    ON CONFLICT (task_name) DO UPDATE SET
        task_function = EXCLUDED.task_function,
        interval_seconds = EXCLUDED.interval_seconds,
        next_run = NOW() + (interval_seconds || ' seconds')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

-- Create scheduled tasks table
CREATE TABLE IF NOT EXISTS config.scheduled_tasks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    task_name TEXT UNIQUE NOT NULL,
    task_function TEXT NOT NULL,
    interval_seconds INTEGER NOT NULL,
    last_run TIMESTAMPTZ,
    next_run TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Schedule maintenance tasks
SELECT maintenance.schedule_task('cleanup-cache', 'SELECT maintenance.cleanup_expired_cache();', 3600);
SELECT maintenance.schedule_task('cleanup-sync-log', 'SELECT maintenance.cleanup_sync_log();', 86400);

EOF

echo "PostgreSQL extensions installation completed!"

# Create monitoring directories
mkdir -p monitoring/grafana/dashboards
mkdir -p monitoring/grafana/datasources

# Create Prometheus configuration
cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']
    metrics_path: /metrics
    scrape_interval: 10s

  - job_name: 'redis'
    static_configs:
      - targets: ['redis:6379']
    scrape_interval: 10s

  - job_name: 'backend'
    static_configs:
      - targets: ['backend:8080']
    scrape_interval: 10s
EOF

# Create Grafana datasource configuration
cat > monitoring/grafana/datasources/datasource.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

# Create basic Grafana dashboard
cat > monitoring/grafana/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

echo "Monitoring configuration created!"
echo "PostgreSQL extensions setup completed successfully!" 