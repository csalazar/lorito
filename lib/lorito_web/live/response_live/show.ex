defmodule LoritoWeb.ResponseLive.Show do
  use LoritoWeb, :live_view

  alias Lorito.Responses

  @impl true
  def mount(
        %{"id" => response_id, "project_id" => project_id, "workspace_id" => workspace_id},
        _session,
        socket
      ) do
    {:ok,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:project, Lorito.Projects.get_project_by_id!(project_id))
     |> assign(
       :workspace,
       Lorito.Workspaces.get_workspace!(%{id: workspace_id, project_id: project_id})
     )
     |> assign(:response, Responses.get_response_by_id!(response_id))}
  end

  @impl true
  def handle_params(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {LoritoWeb.ResponseLive.FormComponent, {:saved, response}},
        socket
      ) do
    {:noreply, assign(socket, :response, response)}
  end

  defp page_title(:show), do: "Show Response"
  defp page_title(:edit), do: "Edit Response"
end
