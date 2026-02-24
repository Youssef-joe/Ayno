package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"
)

var clickHouseIdentifierRegex = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)

type ClickHouseSink struct {
	client        *http.Client
	httpURL       string
	database      string
	username      string
	password      string
	table         string
	batchSize     int
	flushInterval time.Duration
	queue         chan Event
	stop          chan struct{}
	wg            sync.WaitGroup
}

func NewClickHouseSinkFromEnv() (*ClickHouseSink, error) {
	sink := &ClickHouseSink{
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
		httpURL:       strings.TrimSpace(os.Getenv("CLICKHOUSE_HTTP_URL")),
		database:      strings.TrimSpace(os.Getenv("CLICKHOUSE_DATABASE")),
		username:      strings.TrimSpace(os.Getenv("CLICKHOUSE_USERNAME")),
		password:      os.Getenv("CLICKHOUSE_PASSWORD"),
		table:         sanitizeIdentifier(os.Getenv("CLICKHOUSE_TABLE"), "event_analytics"),
		batchSize:     maxInt(envInt("CLICKHOUSE_BATCH_SIZE", 500), 1),
		flushInterval: time.Duration(maxInt(envInt("CLICKHOUSE_FLUSH_INTERVAL_MS", 2000), 100)) * time.Millisecond,
		queue:         make(chan Event, maxInt(envInt("CLICKHOUSE_QUEUE_SIZE", 10000), 100)),
		stop:          make(chan struct{}),
	}

	if sink.httpURL == "" {
		sink.httpURL = "http://localhost:8123"
	}

	if sink.database == "" {
		sink.database = "default"
	}

	if sink.username == "" {
		sink.username = "default"
	}

	if envBool("CLICKHOUSE_AUTO_CREATE", true) {
		if err := sink.ensureTable(); err != nil {
			return nil, err
		}
	}

	sink.wg.Add(1)
	go sink.runWriter()
	log.Printf("ClickHouse analytics sink enabled (table=%s, batch_size=%d)", sink.table, sink.batchSize)

	return sink, nil
}

func (s *ClickHouseSink) WriteEvent(_ context.Context, event Event) {
	select {
	case s.queue <- event:
	default:
		log.Printf("ClickHouse queue is full, dropping event %s", event.ID)
	}
}

func (s *ClickHouseSink) Close() error {
	close(s.stop)
	s.wg.Wait()
	return nil
}

func (s *ClickHouseSink) runWriter() {
	defer s.wg.Done()

	ticker := time.NewTicker(s.flushInterval)
	defer ticker.Stop()

	batch := make([]Event, 0, s.batchSize)
	flush := func() {
		if len(batch) == 0 {
			return
		}

		if err := s.flushBatch(batch); err != nil {
			log.Printf("ClickHouse flush failed: %v", err)
		}
		batch = batch[:0]
	}

	for {
		select {
		case event := <-s.queue:
			batch = append(batch, event)
			if len(batch) >= s.batchSize {
				flush()
			}

		case <-ticker.C:
			flush()

		case <-s.stop:
			for {
				select {
				case event := <-s.queue:
					batch = append(batch, event)
				default:
					flush()
					return
				}
			}
		}
	}
}

func (s *ClickHouseSink) flushBatch(events []Event) error {
	var payload bytes.Buffer

	for _, event := range events {
		row := map[string]string{
			"event_id":    event.ID,
			"app_id":      event.AppID,
			"channel":     event.Channel,
			"event_type":  event.Type,
			"event_time":  formatDateTime64(extractEventTime(event)),
			"data_json":   mustMarshalJSON(event.Data),
			"meta_json":   mustMarshalJSON(event.Meta),
			"ingested_at": formatDateTime64(time.Now().UTC()),
		}

		encoded, err := json.Marshal(row)
		if err != nil {
			return err
		}

		payload.Write(encoded)
		payload.WriteByte('\n')
	}

	insertQuery := fmt.Sprintf("INSERT INTO %s FORMAT JSONEachRow", s.table)
	return s.executeQuery(insertQuery, &payload)
}

func (s *ClickHouseSink) ensureTable() error {
	query := fmt.Sprintf(`
CREATE TABLE IF NOT EXISTS %s (
  event_id String,
  app_id String,
  channel String,
  event_type String,
  event_time DateTime64(3),
  data_json String,
  meta_json String,
  ingested_at DateTime64(3)
) ENGINE = MergeTree
PARTITION BY toYYYYMM(event_time)
ORDER BY (app_id, channel, event_time, event_id)
`, s.table)

	return s.executeQuery(query, nil)
}

func (s *ClickHouseSink) executeQuery(query string, body io.Reader) error {
	base, err := url.Parse(strings.TrimRight(s.httpURL, "/"))
	if err != nil {
		return err
	}

	values := url.Values{}
	values.Set("database", s.database)
	values.Set("query", query)
	base.RawQuery = values.Encode()

	req, err := http.NewRequestWithContext(context.Background(), http.MethodPost, base.String(), body)
	if err != nil {
		return err
	}

	req.SetBasicAuth(s.username, s.password)
	resp, err := s.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= http.StatusBadRequest {
		responseBody, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return fmt.Errorf("clickhouse status=%d body=%s", resp.StatusCode, strings.TrimSpace(string(responseBody)))
	}

	return nil
}

func extractEventTime(event Event) time.Time {
	if event.Meta == nil {
		return time.Now().UTC()
	}

	rawTS, ok := event.Meta["ts"]
	if !ok {
		return time.Now().UTC()
	}

	ts, ok := rawTS.(string)
	if !ok {
		return time.Now().UTC()
	}

	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02 15:04:05",
	}

	for _, layout := range layouts {
		parsed, err := time.Parse(layout, ts)
		if err == nil {
			return parsed.UTC()
		}
	}

	return time.Now().UTC()
}

func formatDateTime64(t time.Time) string {
	return t.UTC().Format("2006-01-02 15:04:05.000")
}

func mustMarshalJSON(value interface{}) string {
	if value == nil {
		return "{}"
	}

	encoded, err := json.Marshal(value)
	if err != nil {
		return "{}"
	}

	return string(encoded)
}

func sanitizeIdentifier(raw, fallback string) string {
	value := strings.TrimSpace(raw)
	if value == "" {
		return fallback
	}

	if clickHouseIdentifierRegex.MatchString(value) {
		return value
	}

	return fallback
}

func maxInt(value, minValue int) int {
	if value < minValue {
		return minValue
	}
	return value
}
