FROM elixir:1.17-alpine AS builder

RUN apk add --no-cache git

WORKDIR /app

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN MIX_ENV=prod mix deps.compile

COPY . .
RUN MIX_ENV=prod mix compile
RUN MIX_ENV=prod mix release

FROM alpine:latest

RUN apk add --no-cache openssl ncurses-libs

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/polyglot ./

EXPOSE 4000

CMD ["bin/polyglot", "start"]
