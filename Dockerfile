# Dockerfile for Supabase Self-hosted
FROM postgres:15

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    git \
    nodejs \
    npm \
    python3 \
    python3-pip \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Supabase CLI
RUN npm install -g supabase

# Set working directory
WORKDIR /app

# Copy Supabase configuration files
COPY supabase/ ./supabase/
COPY .env ./
COPY docker-compose.yml ./

# Expose ports
EXPOSE 54321 54322 54323 54324 54325 54326

# Default command
CMD ["supabase", "start"]