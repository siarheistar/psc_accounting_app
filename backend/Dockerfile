# Dockerfile

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y gcc libpq-dev && rm -rf /var/lib/apt/lists/*

# Copy requirements from backend directory (build context is root)
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all backend source files from backend directory
COPY backend/ .

# Expose FastAPI port
EXPOSE 8000

# Set Python path to ensure modules can be found
ENV PYTHONPATH=/app

# Test that main.py exists and basic structure is correct (without full import)
RUN python -c "import os; assert os.path.exists('main.py'), 'main.py not found'; print('✅ Files copied correctly')"

# Start the FastAPI server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]