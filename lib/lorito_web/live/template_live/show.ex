defmodule LoritoWeb.TemplateLive.Show do
  use LoritoWeb, :live_view

  alias Lorito.Templates
  alias Lorito.Responses.Response
  alias Lorito.Responses

  @impl true
  def mount(%{"template_id" => template_id}, _session, socket) do
    template = Lorito.Templates.get_template!(template_id)

    {:ok, socket |> stream(:responses, template.responses)}
  end

  @impl true
  def handle_params(%{"template_id" => id} = params, _, socket) do
    response =
      case Map.get(params, "response_id") do
        nil -> %Response{}
        response_id -> Responses.get_response!(response_id)
      end

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:template, Templates.get_template!(id))
     |> assign(:response, response)}
  end

  defp page_title(:show), do: "Show Template"
  defp page_title(:edit), do: "Edit Template"
  defp page_title(:new_response), do: "New response"
  defp page_title(:edit_response), do: "Edit response"

  @impl true
  def handle_info(
        {LoritoWeb.ResponseLive.FormComponent, {:saved, _response}},
        %{assigns: %{template: template}} = socket
      ) do
    template = Templates.get_template!(template.id)

    {:noreply,
     socket |> stream(:responses, template.responses, reset: true) |> assign(template: template)}
  end

  @impl true
  def handle_info({LoritoWeb.TemplateLive.FormComponent, {:saved, _template}}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_response", %{"id" => id}, %{assigns: %{template: template}} = socket) do
    response = Responses.get_response!(id)
    {:ok, _} = Responses.delete_response(response)

    template = Templates.get_template!(template.id)

    {:noreply,
     socket
     |> stream(:responses, template.responses, reset: true)
     |> assign(template: template)}
  end
end
