defmodule Polyglot.Pb.Processor do
  @moduledoc """
  Generated protobuf code for processor service.
  This file is auto-generated from proto/processor.proto
  """

  use Protobuf, syntax: :proto3

  field :id, 1, type: :string
  field :app_id, 2, type: :string
  field :channel, 3, type: :string
  field :type, 4, type: :string
  field :data, 5, repeated: true, type: Polyglot.Pb.Processor.DataEntry, map: true
  field :meta, 6, repeated: true, type: Polyglot.Pb.Processor.MetaEntry, map: true

  defmodule DataEntry do
    @moduledoc false
    use Protobuf, map: true, syntax: :proto3
    field :key, 1, type: :string
    field :value, 2, type: :string
  end

  defmodule MetaEntry do
    @moduledoc false
    use Protobuf, map: true, syntax: :proto3
    field :key, 1, type: :string
    field :value, 2, type: :string
  end
end

defmodule Polyglot.Pb.ProcessRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3
  field :event, 1, type: Polyglot.Pb.Processor
end

defmodule Polyglot.Pb.ProcessResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  field :processed, 1, type: :bool
  field :duration_ms, 2, type: :int64
  field :error, 3, type: :string
end

defmodule Polyglot.Pb.ProcessBatchRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3
  field :events, 1, repeated: true, type: Polyglot.Pb.Processor
end

defmodule Polyglot.Pb.ProcessBatchResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  field :processed, 1, type: :int32
  field :failed, 2, type: :int32
  field :total, 3, type: :int32
  field :duration_ms, 4, type: :int64
  field :errors, 5, repeated: true, type: :string
end

defmodule Polyglot.Pb.HealthRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3
end

defmodule Polyglot.Pb.HealthResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  field :status, 1, type: :string
end

defmodule Polyglot.Pb.Processor.Service do
  @moduledoc false
  use GRPC.Service, name: "polyglot.Processor"

  rpc :Process, Polyglot.Pb.ProcessRequest, Polyglot.Pb.ProcessResponse
  rpc :ProcessBatch, Polyglot.Pb.ProcessBatchRequest, Polyglot.Pb.ProcessBatchResponse
  rpc :Health, Polyglot.Pb.HealthRequest, Polyglot.Pb.HealthResponse
end
