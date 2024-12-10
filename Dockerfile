# Use a minimal base image (Ubuntu)
FROM ubuntu:22.04

# Set environment variables and install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    libssl-dev \
    git \
    curl \
    protobuf-compiler \
    cargo \
    && apt-get clean

# Install Rust (needed for Nexus node)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Set Rust environment path
ENV PATH="/root/.cargo/bin:${PATH}"

# Copy the prover-id file into the container
COPY prover-id /root/.nexus/prover-id

# Set the default command to run the Nexus node setup script, automatically agreeing to the terms
CMD ["sh", "-c", "echo Y | curl https://cli.nexus.xyz/ | sh & tail -f /dev/null"]
