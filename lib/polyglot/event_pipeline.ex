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
    processor_url = System.get_env("GO_PROCESSOR_URL", "http://localhost:8080")

    try do
      case HTTPoison.post(
             "#{processor_url}/process",
             Jason.encode!(event),
             [{"Content-Type", "application/json"}],
             timeout: 5000
           ) do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          Logger.debug("Event processed: #{event.id}")
          :ok

        {:ok, response} ->
          Logger.error("Go processor error: #{response.status_code}")
          :error

        {:error, reason} ->
          Logger.error("Failed to reach Go processor: #{inspect(reason)}")
          :error
      end
    rescue
      e ->
        Logger.error("Exception forwarding event: #{inspect(e)}")
        :error
    end
  end
end
