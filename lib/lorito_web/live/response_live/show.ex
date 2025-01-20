defmodule LoritoWeb.ResponseLive.Show do
  use LoritoWeb, :live_view

  alias Lorito.Responses

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:response, Responses.get_response!(id))}
  end

  defp page_title(:show), do: "Show Response"
  defp page_title(:edit), do: "Edit Response"
end
