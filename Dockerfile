FROM python:3.12-slim

WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY backend/ ./backend/
COPY frontend/ ./frontend/

# Expose port
EXPOSE 8888

# Run the server
CMD ["python", "-c", "\
import uvicorn; \
from fastapi.staticfiles import StaticFiles; \
import sys; sys.path.insert(0, 'backend'); \
from main import app; \
app.mount('/dashboard', StaticFiles(directory='frontend', html=True), name='frontend'); \
uvicorn.run(app, host='0.0.0.0', port=8888) \
"]
