defmodule Lorito.Projects.ProjectRepo do
  import Ecto.Query, warn: false
  alias Lorito.Repo

  alias Lorito.Projects.Project
  alias Lorito.Accounts.User

  def list_projects(_filters \\ %{}) do
    Repo.all(Project) |> Repo.preload(:user)
  end

  def get_project!(id), do: Repo.get!(Project, id) |> Repo.preload(:user)

  def get_project(%{subdomain: nil}), do: nil

  def get_project(%{subdomain: subdomain}) do
    Project
    |> where([p], p.subdomain == ^subdomain)
    |> Repo.one()
  end

  def create_project(attrs \\ %{}) do
    caller = User.get_user_from_process()

    %Project{}
    |> Project.changeset(attrs)
    |> User.put_user(caller)
    |> Repo.insert()
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end
end
