defmodule LoritoWeb.LogLive.Index do
  use LoritoWeb, :live_view

  alias Lorito.Logs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Listing Logs") |> stream(:logs, [])}
  end

  @impl true
  def handle_params(params, uri, socket) do
    filters = %{scoped_logs: params["scoped_logs"] == "true"}

    {:noreply,
     socket |> assign(:filters, filters) |> LoritoWeb.LogPagination.load(params, uri, filters)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "create",
          payload: %{data: log}
        },
        socket
      ) do
    {:noreply, LoritoWeb.LogPagination.created(socket, log)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    log = Logs.get_log_by_id!(id)
    :ok = Logs.delete_log!(log)

    {:noreply, LoritoWeb.LogPagination.reload(socket)}
  end

  @impl true
  def handle_event("delete_catch_all", _params, socket) do
    :ok = Logs.delete_logs_by_type(:catch_all)

    {:noreply, LoritoWeb.LogPagination.reload(socket)}
  end

  @impl true
  def handle_event("ip_delete", %{"ip" => ip}, socket) do
    :ok = Logs.delete_logs_by_ip(ip)

    {:noreply, LoritoWeb.LogPagination.reload(socket)}
  end

  @impl true
  def handle_event("toggle_scoped_logs_filter", params, socket) do
    enabled = Map.get(params, "value", "off") == "true"
    {:noreply, push_patch(socket, to: ~p"/_lorito/logs?#{%{scoped_logs: enabled}}")}
  end
end
