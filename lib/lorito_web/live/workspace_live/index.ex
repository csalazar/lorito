defmodule LoritoWeb.WorkspaceLive.Index do
  use LoritoWeb, :live_view

  alias Lorito.Workspaces
  alias Lorito.Workspaces.Workspace
  alias Lorito.Projects

  @impl true
  def mount(%{"project_id" => project_id}, _session, socket) do
    project = Projects.get_project_by_id!(project_id)

    {:ok,
     socket
     |> assign(:project, project)
     |> stream(
       :workspaces,
       Workspaces.list_workspaces_by_project!(project_id, load: [:template])
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Workspaces")
    |> assign(:workspace, nil)
  end

  defp apply_action(%{assigns: %{project: project}} = socket, :edit, %{"workspace_id" => id}) do
    socket
    |> assign(:page_title, "Edit Workspace")
    |> assign(:workspace, Workspaces.get_workspace!(%{id: id, project_id: project.id}))
  end

  defp apply_action(socket, :add_new_workspace_from_template, _params) do
    socket
    |> assign(:page_title, "New Workspace")
    |> assign(:workspace, %Workspace{})
  end

  defp apply_action(socket, :edit_project, _params) do
    socket
    |> assign(:page_title, "Edit Project")
    |> assign(:workspace, %Workspace{})
  end

  @impl true
  def handle_info({_, {:saved, %Workspace{} = workspace}}, socket) do
    workspace = Workspaces.get_workspace!(%{id: workspace.id, project_id: workspace.project_id})
    {:noreply, stream_insert(socket, :workspaces, workspace)}
  end

  @impl true
  def handle_info({_, {:saved, project}}, socket) do
    {:noreply, assign(socket, :project, project)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, %{assigns: %{project: project}} = socket) do
    workspace = Workspaces.get_workspace!(%{id: id, project_id: project.id})
    :ok = Workspaces.delete_workspace(workspace)

    {:noreply, stream_delete(socket, :workspaces, workspace)}
  end

  @impl true
  def handle_event(
        "add_new_workspace",
        _,
        %{assigns: %{project: project, current_user: current_user}} = socket
      ) do
    workspace = Workspaces.create_workspace!(%{project_id: project.id}, actor: current_user)
    # load again to get all the fields
    workspace = Workspaces.get_workspace!(%{id: workspace.id, project_id: project.id})

    {:noreply, stream_insert(socket, :workspaces, workspace)}
  end
end
