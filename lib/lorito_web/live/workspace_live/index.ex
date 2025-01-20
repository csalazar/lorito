defmodule LoritoWeb.WorkspaceLive.Index do
  use LoritoWeb, :live_view

  alias Lorito.Workspaces
  alias Lorito.Workspaces.Workspace

  @impl true
  def mount(_params, _session, %{assigns: %{project: project}} = socket) do
    {:ok, stream(socket, :workspaces, Workspaces.list_workspaces(%{project: project}))}
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

  defp apply_action(socket, :edit, %{"workspace_id" => id}) do
    socket
    |> assign(:page_title, "Edit Workspace")
    |> assign(:workspace, Workspaces.get_workspace!(id))
  end

  defp apply_action(socket, :add_new_workspace_from_template, _params) do
    socket
    |> assign(:page_title, "New Workspace")
    |> assign(:workspace, %Workspace{})
  end

  @impl true
  def handle_info({_, {:saved, %Workspace{} = workspace}}, socket) do
    workspace = Workspaces.get_workspace!(workspace.id)
    {:noreply, stream_insert(socket, :workspaces, workspace)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    workspace = Workspaces.get_workspace!(id)
    {:ok, _} = Workspaces.delete_workspace(workspace)

    {:noreply, stream_delete(socket, :workspaces, workspace)}
  end

  @impl true
  def handle_event("add_new_workspace", _, %{assigns: %{project: project}} = socket) do
    {:ok, workspace} = Workspaces.create_workspace(%{"project" => project})
    workspace = Workspaces.get_workspace!(workspace.id)

    {:noreply, stream_insert(socket, :workspaces, workspace)}
  end
end
