FROM swift:5.10-jammy

# Install required dependencies for Linux
RUN apt-get update && apt-get install -y \
    libssl-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Clean package state and build
RUN rm -rf .build Package.resolved && swift build && swift test
