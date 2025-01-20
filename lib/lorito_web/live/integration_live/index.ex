defmodule LoritoWeb.IntegrationLive.Index do
  use LoritoWeb, :live_view

  alias Lorito.Integrations
  alias Lorito.Integrations.Integration

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :integrations, Integrations.list_integrations())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Integration")
    |> assign(:integration, Integrations.get_integration!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Integration")
    |> assign(:integration, %Integration{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Integrations")
    |> assign(:integration, nil)
  end

  @impl true
  def handle_info({LoritoWeb.IntegrationLive.FormComponent, {:saved, integration}}, socket) do
    {:noreply, stream_insert(socket, :integrations, integration)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    integration = Integrations.get_integration!(id)
    {:ok, _} = Integrations.delete_integration(integration)

    {:noreply, stream_delete(socket, :integrations, integration)}
  end

  @impl true
  def handle_event("send_probe", %{"id" => id}, socket) do
    {:ok, _} = Integrations.get_integration!(id) |> Integrations.send_probe()

    {:noreply,
     socket
     |> put_flash(:info, "Probe sent successfully")}
  end
end
