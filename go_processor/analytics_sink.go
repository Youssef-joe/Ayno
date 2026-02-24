package main

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
)

type AnalyticsSink interface {
	WriteEvent(ctx context.Context, event Event)
	Close() error
}

type NoopAnalyticsSink struct{}

func (NoopAnalyticsSink) WriteEvent(_ context.Context, _ Event) {}
func (NoopAnalyticsSink) Close() error                          { return nil }

func NewAnalyticsSinkFromEnv() (AnalyticsSink, error) {
	backend := strings.ToLower(strings.TrimSpace(os.Getenv("ANALYTICS_BACKEND")))
	if backend == "" || backend == "none" {
		return NoopAnalyticsSink{}, nil
	}

	if backend == "clickhouse" {
		return NewClickHouseSinkFromEnv()
	}

	return nil, fmt.Errorf("unsupported analytics backend: %s", backend)
}

func envInt(key string, defaultValue int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return defaultValue
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return defaultValue
	}

	return parsed
}

func envBool(key string, defaultValue bool) bool {
	value := strings.ToLower(strings.TrimSpace(os.Getenv(key)))
	if value == "" {
		return defaultValue
	}

	switch value {
	case "1", "true", "yes", "on":
		return true
	default:
		return false
	}
}
