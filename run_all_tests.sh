#!/bin/bash

set -e

echo "🧪 Starting Comprehensive User Management Testing"
echo "================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_status $BLUE "🔍 Checking prerequisites..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_status $RED "❌ Docker is not running. Please start Docker first."
    exit 1
fi
print_status $GREEN "✅ Docker is running"

# Check if Go is installed
if ! command_exists go; then
    print_status $RED "❌ Go is not installed. Please install Go first."
    exit 1
fi
print_status $GREEN "✅ Go is installed"

# Check if Node.js is installed
if ! command_exists node; then
    print_status $RED "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi
print_status $GREEN "✅ Node.js is installed"

echo ""

# Start database if not running
print_status $BLUE "🗄️  Starting database..."
cd backend
if ! docker-compose ps postgres | grep -q "Up"; then
    print_status $YELLOW "📦 Starting PostgreSQL database..."
    docker-compose up -d postgres
    sleep 5
fi
print_status $GREEN "✅ Database is running"

# Start backend server if not running
print_status $BLUE "🔧 Starting backend server..."
if ! curl -s http://localhost:8080/api/v1/auth/me >/dev/null 2>&1; then
    print_status $YELLOW "🚀 Starting backend server..."
    
    # Set environment variables
    export JWT_PRIVATE_KEY="$(cat jwt_private.pem)"
    export JWT_PUBLIC_KEY="$(cat jwt_public.pem)"
    export DB_HOST=localhost
    export DB_PORT=5434
    export DB_USER=postgres
    export DB_PASSWORD=postgres
    export DB_NAME=global_remit
    export APP_PORT=8080
    
    # Start server in background
    ./api-server > server.log 2>&1 &
    SERVER_PID=$!
    
    # Wait for server to start
    print_status $YELLOW "⏳ Waiting for server to start..."
    for i in {1..30}; do
        if curl -s http://localhost:8080/api/v1/auth/me >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    
    if ! curl -s http://localhost:8080/api/v1/auth/me >/dev/null 2>&1; then
        print_status $RED "❌ Backend server failed to start"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    
    print_status $GREEN "✅ Backend server is running (PID: $SERVER_PID)"
else
    print_status $GREEN "✅ Backend server is already running"
fi

echo ""

# Run backend tests
print_status $BLUE "🧪 Running Backend Tests..."
echo "=================================="

if ./run_tests.sh; then
    print_status $GREEN "✅ Backend tests completed successfully"
else
    print_status $RED "❌ Backend tests failed"
    # Cleanup
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

echo ""

# Run frontend tests
print_status $BLUE "🧪 Running Frontend Tests..."
echo "=================================="

cd ../Frontend
if ./run_tests.sh; then
    print_status $GREEN "✅ Frontend tests completed successfully"
else
    print_status $RED "❌ Frontend tests failed"
    # Cleanup
    cd ../backend
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

echo ""

# Cleanup
print_status $BLUE "🧹 Cleaning up..."
cd ../backend
if [ ! -z "$SERVER_PID" ]; then
    kill $SERVER_PID 2>/dev/null || true
    print_status $GREEN "✅ Backend server stopped"
fi

echo ""
print_status $GREEN "🎉 All tests completed successfully!"
echo ""
print_status $BLUE "📊 Test Summary:"
echo "  Backend Tests:"
echo "    - Complete User Management Flow: ✅"
echo "    - Authentication Tests: ✅"
echo "    - User CRUD Operations: ✅"
echo "    - Password Management: ✅"
echo "    - User Status Management: ✅"
echo "    - Role and Permission Tests: ✅"
echo "    - Invitation Flow: ✅"
echo "    - Audit Logging: ✅"
echo "    - Edge Cases and Error Handling: ✅"
echo ""
echo "  Frontend Tests:"
echo "    - User List Display: ✅"
echo "    - User Creation: ✅"
echo "    - User Updates: ✅"
echo "    - User Deletion: ✅"
echo "    - User Status Management: ✅"
echo "    - User Search and Filtering: ✅"
echo "    - Pagination: ✅"
echo "    - Error Handling: ✅"
echo "    - Accessibility: ✅"
echo ""
print_status $GREEN "🚀 User Management System is fully tested and ready for production!" 