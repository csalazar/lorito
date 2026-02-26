defmodule LoritoWeb.TemplateLive.Index do
  use LoritoWeb, :live_view

  alias Lorito.Templates
  alias Lorito.Templates.Template

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :templates, Templates.list_templates!())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Template")
    |> assign(:template, Templates.get_template_by_id!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Template")
    |> assign(:template, %Template{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Templates")
    |> assign(:template, nil)
  end

  @impl true
  def handle_info({LoritoWeb.TemplateLive.FormComponent, {:saved, template}}, socket) do
    {:noreply, stream_insert(socket, :templates, template)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    template = Templates.get_template_by_id!(id)
    :ok = Templates.delete_template!(template)

    {:noreply, stream_delete(socket, :templates, template)}
  end
end
