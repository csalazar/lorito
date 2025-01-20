defmodule Lorito.Workspaces.WorkspaceRepo do
  import Ecto.Query, warn: false
  alias Lorito.Repo

  alias Lorito.Workspaces.Workspace
  alias Lorito.Responses.Response
  alias Lorito.Logs.Log
  alias Lorito.Projects.Project
  alias Lorito.Templates.Template
  alias Lorito.Accounts.User

  def filter_by_project(query, %{project: %Project{} = project}) do
    where(query, project_id: ^project.id)
  end

  def filter_by_project(query, %{project: project_id})
      when is_binary(project_id) and project_id != "" do
    where(query, project_id: ^project_id)
  end

  def filter_by_path(query, %{path: path}) when is_binary(path) do
    where(query, path: ^path)
  end

  def filter_by_id(query, %{id: id}) when is_binary(id) and id != "" do
    where(query, id: ^id)
  end

  def list_workspaces(filters) when is_map(filters) do
    Workspace
    |> filter_by_project(filters)
    |> Repo.all()
    |> Repo.preload([:project, :template])
  end

  def get_workspace!(id) do
    query =
      from(
        v in Workspace,
        where: v.id == ^id,
        preload: [
          logs:
            ^from(
              l in Log,
              order_by: [desc: l.inserted_at]
            ),
          responses:
            ^from(
              r in Response,
              order_by: [asc: r.route, desc: r.inserted_at]
            )
        ]
      )

    query |> Repo.one!() |> Repo.preload([:project, :template])
  end

  def get_workspace(%{project: _project_id, id: _workspace_id} = filters)
      when is_map(filters) do
    Workspace
    |> filter_by_project(filters)
    |> filter_by_id(filters)
    |> Repo.one()
    |> Repo.preload([:responses, :template])
  end

  def get_workspace(%{path: _path} = filters) when is_map(filters) do
    Workspace
    |> filter_by_path(filters)
    |> Repo.one()
    |> Repo.preload([:responses, :template])
  end

  def create_workspace(attrs) do
    caller = User.get_user_from_process()

    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Project.put_project(attrs["project"])
    |> Template.put_template(attrs["template"])
    |> User.put_user(caller)
    |> Repo.insert()
  end

  def update_workspace(%Workspace{} = workspace, attrs) do
    workspace
    |> Workspace.changeset_update(attrs)
    |> Repo.update()
  end

  def delete_workspace(%Workspace{} = workspace) do
    Repo.delete(workspace)
  end

  def change_workspace(%Workspace{} = workspace, attrs \\ %{}) do
    Workspace.changeset(workspace, attrs)
  end
end
