FROM nvidia/cuda:11.8.0-devel-ubuntu22.04

# Set non-interactive mode for apt installations
ENV DEBIAN_FRONTEND=noninteractive

# Update apt repositories and install python, pip, development libraries
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    python3-setuptools \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Set up symbolic link for python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Create application workspace
WORKDIR /app

# Copy python requirements
COPY requirements.txt .

# Ensure pip is up to date and install dependencies
# We set high timeout to avoid network timeouts during compilation
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir -r requirements.txt || \
    (echo "WARNING: Failed to install pycuda. Attempting to install fallback CPU requirements..." && \
     sed -i '/pycuda/d' requirements.txt && \
     pip3 install --no-cache-dir -r requirements.txt)

# Copy application source code
COPY . .

# Expose port for FastAPI
EXPOSE 8000

# Set environment variables
ENV HOST=0.0.0.0
ENV PORT=8000

# Command to run FastAPI server
CMD ["python", "main.py"]
