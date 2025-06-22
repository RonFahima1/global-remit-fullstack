#!/bin/sh
set -e

# Wait for Postgres to be ready
until pg_isready -U "$POSTGRES_USER"; do
  echo "Waiting for postgres..."
  sleep 1
done

# Check if the DB is empty (no tables)
TABLE_COUNT=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")

if [ "$TABLE_COUNT" -eq "0" ] && [ -f /docker-entrypoint-initdb.d/postgres_snapshot.sql ]; then
  echo "Restoring database from snapshot..."
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < /docker-entrypoint-initdb.d/postgres_snapshot.sql
  echo "Database restored from snapshot."
else
  echo "Database already initialized or snapshot missing."
fi 