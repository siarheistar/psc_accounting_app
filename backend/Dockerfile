# Dockerfile

FROM python:3.11-slim

# Use repo root as context; we will copy only what's needed
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
	gcc libpq-dev \
 && rm -rf /var/lib/apt/lists/*

# Copy backend requirements and install
COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

# Copy backend source
COPY backend/ /app/backend/

# Set working dir to backend where main.py resides
WORKDIR /app/backend

# Expose FastAPI port
EXPOSE 8000

# Start the FastAPI server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]