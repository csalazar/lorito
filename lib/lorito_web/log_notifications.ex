defmodule LoritoWeb.LogNotifications do
  @moduledoc false

  def on_mount(:default, _params, _session, socket) do
    if Phoenix.LiveView.connected?(socket) do
      Phoenix.PubSub.subscribe(Lorito.PubSub, "log:created")
    end

    {:cont,
     Phoenix.LiveView.attach_hook(socket, :desktop_notifications, :handle_info, &handle_info/2)}
  end

  defp handle_info(
         %Phoenix.Socket.Broadcast{topic: "log:created", event: "create", payload: %{data: data}},
         socket
       ) do
    socket =
      case Lorito.Logs.get_log_by_id(data.id) do
        {:ok, log} when not is_nil(log) -> push(socket, log)
        _ -> socket
      end

    # The logs index also consumes this event to update its table. Other pages
    # must not receive global events in their workspace-specific handlers.
    if socket.view == LoritoWeb.LogLive.Index, do: {:cont, socket}, else: {:halt, socket}
  end

  defp handle_info(_message, socket), do: {:cont, socket}

  def push(socket, log) do
    context =
      [log.project && log.project.name, log.workspace && log.workspace.displayable_name]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" / ")

    Phoenix.LiveView.push_event(socket, "log-created", %{
      id: log.id,
      protocol: log.protocol,
      workspace_id: log.workspace_id,
      title: "New #{String.upcase(to_string(log.protocol))} log",
      body: if(context == "", do: "Catch-all log received", else: String.slice(context, 0, 160)),
      url: "/_lorito/logs/#{log.id}"
    })
  end
end
