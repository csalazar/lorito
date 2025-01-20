defmodule Lorito.Logs.PubSub do
  alias Lorito.Logs.Log

  @topic inspect(__MODULE__)

  # PubSub
  # Global logs
  def subscribe() do
    Phoenix.PubSub.subscribe(Lorito.PubSub, @topic)
  end

  # Workspace logs
  def subscribe(workspace_id) do
    Phoenix.PubSub.subscribe(Lorito.PubSub, @topic <> "#{workspace_id}")
  end

  def notify_subscribers({:ok, %Log{} = log}, event) do
    # Send catch-all message
    Phoenix.PubSub.broadcast(
      Lorito.PubSub,
      @topic,
      {__MODULE__, event, log}
    )

    # Send workspace message (a catch-all log doesn't have a workspace)
    if log.workspace_id do
      Phoenix.PubSub.broadcast(
        Lorito.PubSub,
        @topic <> "#{log.workspace_id}",
        {__MODULE__, event, log}
      )
    end

    {:ok, log}
  end

  def notify_subscribers({:error, %Ecto.Changeset{}} = error, _event), do: error
end
