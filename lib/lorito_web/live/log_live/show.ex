defmodule LoritoWeb.LogLive.Show do
  use LoritoWeb, :live_view

  alias Lorito.Logs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, %{assigns: %{live_action: live_action}} = socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Show Log")
     |> assign(:log, Logs.get_log_by_id!(id))
     |> assign(:live_action, live_action)}
  end
end
