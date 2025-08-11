# Dockerfile

FROM python:3.11-slim

# Set working directory to /app/backend to match the project structure
WORKDIR /app/backend

# Install system dependencies (optional: add build-essential if needed)
RUN apt-get update && apt-get install -y gcc libpq-dev

# Copy dependency file and install Python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all backend files to the working directory
COPY . .

# Expose FastAPI port
EXPOSE 8000

# Start the FastAPI server from the backend directory
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]