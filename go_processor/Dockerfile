FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o processor .

FROM alpine:latest

WORKDIR /app

COPY --from=builder /app/processor .

EXPOSE 8080 9090

CMD ["./processor"]
