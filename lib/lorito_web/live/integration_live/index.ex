defmodule LoritoWeb.IntegrationLive.Index do
  use LoritoWeb, :live_view

  alias Lorito.Logs
  alias Lorito.Logs.Integration

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :integrations, Logs.list_integrations!())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Integration")
    |> assign(:integration, Logs.get_integration_by_id!(id))
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
    integration = Logs.get_integration_by_id!(id)
    :ok = Logs.delete_integration(integration)

    {:noreply, stream_delete(socket, :integrations, integration)}
  end

  @impl true
  def handle_event("send_probe", %{"id" => id}, socket) do
    {:ok, _} = Logs.get_integration_by_id!(id) |> Logs.send_integration_probe()

    {:noreply,
     socket
     |> put_flash(:info, "Probe sent successfully")}
  end
end
