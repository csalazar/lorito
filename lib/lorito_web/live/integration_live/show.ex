defmodule LoritoWeb.IntegrationLive.Show do
  use LoritoWeb, :live_view

  alias Lorito.Logs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:integration, Logs.get_integration_by_id!(id))}
  end

  defp page_title(:show), do: "Show Integration"
  defp page_title(:edit), do: "Edit Integration"
end
