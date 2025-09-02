defmodule LoritoWeb.LogLive.Index do
  use LoritoWeb, :live_view

  alias Lorito.Logs

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Logs.PubSub.subscribe()
    filters = %{scoped_logs: false}

    {:ok,
     socket
     |> assign(:page_title, "Listing Logs")
     |> assign(:filters, filters)
     |> stream(:logs, Logs.list_logs(filters))}
  end

  @impl true
  def handle_info({Lorito.Logs.PubSub, [:log, :created], log}, socket) do
    # Load project
    filters = socket.assigns.filters
    log = Logs.get_log!(log.id)

    if filters[:scoped_logs] do
      # If `scoped_logs` filter is enabled, we only want to show logs from a project or workspace
      if log.project_id || log.workspace_id do
        {:noreply, stream_insert(socket, :logs, log, at: 0)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, stream_insert(socket, :logs, log, at: 0)}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    log = Logs.get_log!(id)
    {:ok, _} = Logs.delete_log(log)

    {:noreply, stream_delete(socket, :logs, log)}
  end

  @impl true
  def handle_event("delete_catch_all", _params, socket) do
    {_n, deleted_logs} = Logs.delete_logs(%{type: :catch_all})

    new_socket =
      Enum.reduce(deleted_logs, socket, fn log, acc_socket ->
        stream_delete(acc_socket, :logs, log)
      end)

    {:noreply, new_socket}
  end

  @impl true
  def handle_event("ip_delete", %{"ip" => ip}, socket) do
    {_n, deleted_logs} = Logs.delete_logs(%{ip: ip})

    new_socket =
      Enum.reduce(deleted_logs, socket, fn log, acc_socket ->
        stream_delete(acc_socket, :logs, log)
      end)

    {:noreply, new_socket}
  end

  @impl true
  def handle_event("toggle_scoped_logs_filter", params, socket) do
    enabled = Map.get(params, "value", "off") == "true"
    filters = %{scoped_logs: enabled}

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> stream(:logs, Logs.list_logs(filters), reset: true)}
  end
end
