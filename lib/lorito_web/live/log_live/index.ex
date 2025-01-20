defmodule LoritoWeb.LogLive.Index do
  use LoritoWeb, :live_view

  alias Lorito.Logs

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Logs.PubSub.subscribe()

    {:ok,
     socket
     |> assign(:page_title, "Listing Logs")
     |> stream(:logs, Logs.list_logs())}
  end

  @impl true
  def handle_info({Lorito.Logs.PubSub, [:log, :created], log}, socket) do
    # Load project
    log = Logs.get_log!(log.id)
    {:noreply, stream_insert(socket, :logs, log, at: 0)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    log = Logs.get_log!(id)
    {:ok, _} = Logs.delete_log(log)

    {:noreply, stream_delete(socket, :logs, log)}
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
end
