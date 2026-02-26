defmodule LoritoWeb.ResponseLive.Index do
  use LoritoWeb, :live_view

  alias Lorito.Responses
  alias Lorito.Responses.Response

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :responses, Responses.list_responses())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Response")
    |> assign(:response, Responses.get_response_by_id!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Response")
    |> assign(:response, %Response{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Responses")
    |> assign(:response, nil)
  end

  @impl true
  def handle_info({LoritoWeb.ResponseLive.FormComponent, {:saved, response}}, socket) do
    {:noreply, stream_insert(socket, :responses, response)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    response = Responses.get_response_by_id!(id)
    :ok = Responses.delete_response(response)

    {:noreply, stream_delete(socket, :responses, response)}
  end
end
