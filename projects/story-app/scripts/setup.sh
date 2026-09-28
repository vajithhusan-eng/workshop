#!/bin/bash

# Setup script for Multi-AI Agent Orchestrator

set -e

echo "=========================================="
echo " Multi-AI Agent Orchestrator Setup"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python 3 is not installed. Please install Python 3.11+${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python 3 found${NC}"

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Flutter is not installed. Please install Flutter 3.0+${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Flutter found${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker found${NC}"

# Create .env file if not exists
if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${GREEN}✓ Created .env file${NC}"
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

# Setup backend
echo ""
echo "Setting up backend..."
cd backend
pip install -r requirements.txt
pip install uvicorn[standard] aiosqlite playwright
playwright install chromium
echo -e "${GREEN}✓ Backend dependencies installed${NC}"
cd ..

# Setup frontend
echo ""
echo "Setting up frontend..."
cd frontend
flutter pub get
echo -e "${GREEN}✓ Frontend dependencies installed${NC}"
cd ..

# Create data directory
mkdir -p backend/data

# Build Docker images
echo ""
echo "Building Docker images..."
docker-compose build
echo -e "${GREEN}✓ Docker images built${NC}"

echo ""
echo "=========================================="
echo -e "${GREEN}Setup complete! Run 'make dev' to start.${NC}"
echo "=========================================="
