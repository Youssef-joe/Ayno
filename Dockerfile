# Builder stage
FROM elixir:1.17-alpine AS builder

RUN apk add --no-cache git

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
RUN MIX_ENV=prod mix compile

# Build release
RUN MIX_ENV=prod mix release

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs ca-certificates bash

# Create non-root user
RUN addgroup -g 1000 polyglot && \
    adduser -D -u 1000 -G polyglot polyglot

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
