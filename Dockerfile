# Builder stage
FROM elixir:1.17-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git build-essential gcc make postgresql-client libpq-dev protobuf-compiler ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency files
COPY mix.exs mix.lock ./

# Get and compile dependencies
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    MIX_ENV=prod mix deps.compile

# Copy application code
COPY . .

# Compile application
RUN MIX_ENV=prod SECRET_KEY_BASE=placeholder-for-build JWT_SECRET=placeholder-for-build mix compile

# Build release
RUN MIX_ENV=prod SECRET_KEY_BASE=placeholder-for-build JWT_SECRET=placeholder-for-build mix release

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl ca-certificates bash postgresql-client libstdc++6 libgcc1 \
    libncurses6 zlib1g && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -g 1000 polyglot && \
    useradd -m -u 1000 -g polyglot polyglot

WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=polyglot:polyglot /app/_build/prod/rel/polyglot ./

# Switch to non-root user
USER polyglot

EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

CMD ["bin/polyglot", "start"]
