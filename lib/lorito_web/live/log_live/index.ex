defmodule LoritoWeb.LogLive.Index do
  use LoritoWeb, :live_view

  alias Lorito.Logs

  @impl true
  def mount(_params, _session, socket) do
    filters = %{scoped_logs: false}

    {:ok,
     socket
     |> assign(:page_title, "Listing Logs")
     |> assign(:filters, filters)
     |> stream(:logs, Logs.list_logs!(filters))}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "create",
          payload: %{data: log}
        },
        socket
      ) do
    log = Logs.get_log_by_id!(log.id)

    if not socket.assigns.filters[:scoped_logs] or not is_nil(log.project_id) or
         not is_nil(log.workspace_id) do
      {:noreply,
       socket
       |> stream_insert(:logs, log, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    log = Logs.get_log_by_id!(id)
    :ok = Logs.delete_log!(log)

    {:noreply, stream_delete(socket, :logs, log)}
  end

  @impl true
  def handle_event("delete_catch_all", _params, socket) do
    :ok = Logs.delete_logs_by_type(:catch_all)

    {:noreply,
     socket
     |> stream(:logs, Logs.list_logs!(socket.assigns.filters), reset: true)}
  end

  @impl true
  def handle_event("ip_delete", %{"ip" => ip}, socket) do
    :ok = Logs.delete_logs_by_ip(ip)

    {:noreply,
     socket
     |> stream(:logs, Logs.list_logs!(socket.assigns.filters), reset: true)}
  end

  @impl true
  def handle_event("toggle_scoped_logs_filter", params, socket) do
    enabled = Map.get(params, "value", "off") == "true"
    filters = %{scoped_logs: enabled}

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> stream(:logs, Logs.list_logs!(filters), reset: true)}
  end
end
