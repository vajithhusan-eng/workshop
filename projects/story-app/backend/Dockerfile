# Multi-AI Agent Orchestrator - Docker Configuration
# Multi-stage build for production deployment

# === Stage 1: Build ===
FROM python:3.11-slim as builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Install Playwright browsers
RUN pip install --no-cache-dir playwright && \
    playwright install --with-deps chromium

# === Stage 2: Runtime ===
FROM python:3.11-slim as runtime

WORKDIR /app

# Install runtime system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    libpq5 \
    libnss3 \
    libxss1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy installed packages from builder stage
COPY --from=builder /root/.local /root/.local
COPY --from=builder /ms-playwright /ms-playwright

# Set environment variables
ENV PATH=/root/.local/bin:$PATH
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV PYTHONPATH=/app

# Copy application source
COPY . .

# Create necessary directories
RUN mkdir -p ~/.config/multi-ai-orchestrator/chrome && \
    mkdir -p /app/uploads && \
    mkdir -p /app/screenshots

# Expose the application port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start the application
CMD ["python", "run.py"]

# === Alternative: Development Dockerfile ===
# Uncomment below for development with hot-reload
#
# FROM python:3.11-slim as development
# WORKDIR /app
# RUN apt-get update && apt-get install -y curl gcc libpq-dev
# COPY requirements.txt .
# RUN pip install --no-cache-dir -r requirements.txt
# RUN pip install --no-cache-dir playwright && playwright install --with-deps chromium
# COPY . .
# EXPOSE 8000
# CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
