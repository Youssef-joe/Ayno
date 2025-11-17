defmodule Polyglot.EventPipeline do
  @moduledoc """
  Simple event processing pipeline that forwards events to Go processor.
  
  Uses Task.start_link for async processing without blocking.
  """

  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @doc """
  Push an event to be processed (asynchronously).
  """
  def push_event(event) do
    Task.start_link(fn ->
      forward_to_processor(event)
    end)
  end

  # Private helpers

  defp forward_to_processor(event) do
    case Polyglot.ProcessorClient.process_event(event) do
      :ok ->
        Logger.debug("Event processed: #{event.id}")
        :ok

      :error ->
        Logger.error("Failed to process event: #{event.id}")
        :error
    end
  end
end
