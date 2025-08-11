# Dockerfile

FROM python:3.11-slim

# Set working directory to match the backend structure
WORKDIR /app/backend

# Install system dependencies
RUN apt-get update && apt-get install -y gcc libpq-dev && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better Docker layer caching
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all backend source files
COPY backend/ .

# Expose FastAPI port
EXPOSE 8000

# Start the FastAPI server - main.py should be in current directory now
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]