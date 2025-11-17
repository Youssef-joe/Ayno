package main

import (
	"context"
	"log"
	"net"
	"polyglot-processor/pb"
	"time"
)

type Server struct {
	pb.UnimplementedProcessorServer
	processor *Processor
}

func NewServer(processor *Processor) *Server {
	return &Server{processor: processor}
}

func (s *Server) Process(ctx context.Context, req *pb.ProcessRequest) (*pb.ProcessResponse, error) {
	if req.Event == nil {
		return &pb.ProcessResponse{
			Processed: false,
			Error:     "event is required",
		}, nil
	}

	start := time.Now()

	// Convert protobuf event to internal event
	event := Event{
		ID:      req.Event.Id,
		AppID:   req.Event.AppId,
		Channel: req.Event.Channel,
		Type:    req.Event.Type,
		Data:    convertMapToInterface(req.Event.Data),
		Meta:    convertMapToInterface(req.Event.Meta),
	}

	err := s.processor.processEvent(event)
	duration := time.Since(start).Milliseconds()

	if err != nil {
		log.Printf("Error processing event: %v", err)
		return &pb.ProcessResponse{
			Processed: false,
			DurationMs: duration,
			Error:     err.Error(),
		}, nil
	}

	return &pb.ProcessResponse{
		Processed:  true,
		DurationMs: duration,
	}, nil
}

func (s *Server) ProcessBatch(ctx context.Context, req *pb.ProcessBatchRequest) (*pb.ProcessBatchResponse, error) {
	if len(req.Events) == 0 {
		return &pb.ProcessBatchResponse{
			Total: 0,
		}, nil
	}

	start := time.Now()
	processed := int32(0)
	failed := int32(0)
	errors := []string{}

	for _, pbEvent := range req.Events {
		event := Event{
			ID:      pbEvent.Id,
			AppID:   pbEvent.AppId,
			Channel: pbEvent.Channel,
			Type:    pbEvent.Type,
			Data:    convertMapToInterface(pbEvent.Data),
			Meta:    convertMapToInterface(pbEvent.Meta),
		}

		if err := s.processor.processEvent(event); err != nil {
			log.Printf("Error processing event in batch: %v", err)
			failed++
			errors = append(errors, err.Error())
		} else {
			processed++
		}
	}

	duration := time.Since(start).Milliseconds()

	return &pb.ProcessBatchResponse{
		Processed:  processed,
		Failed:     failed,
		Total:      int32(len(req.Events)),
		DurationMs: duration,
		Errors:     errors,
	}, nil
}

func (s *Server) Health(ctx context.Context, req *pb.HealthRequest) (*pb.HealthResponse, error) {
	return &pb.HealthResponse{
		Status: "ok",
	}, nil
}

func convertMapToInterface(m map[string]string) map[string]interface{} {
	result := make(map[string]interface{})
	for k, v := range m {
		result[k] = v
	}
	return result
}

func StartGRPCServer(port string, processor *Processor) error {
	listener, err := net.Listen("tcp", ":"+port)
	if err != nil {
		return err
	}

	grpcServer := NewGrpcServer()
	server := NewServer(processor)

	pb.RegisterProcessorServer(grpcServer, server)

	log.Printf("gRPC server listening on :%s", port)
	return grpcServer.Serve(listener)
}
