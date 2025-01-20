defmodule LoritoWeb.IntegrationLive.Show do
  use LoritoWeb, :live_view

  alias Lorito.Integrations

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:integration, Integrations.get_integration!(id))}
  end

  defp page_title(:show), do: "Show Integration"
  defp page_title(:edit), do: "Edit Integration"
end
