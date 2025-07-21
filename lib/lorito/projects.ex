defmodule Lorito.Projects do
  alias Lorito.Projects.ProjectRepo

  defdelegate list_projects(filters \\ %{}), to: ProjectRepo
  defdelegate get_project!(id), to: ProjectRepo
  defdelegate get_project(filters), to: ProjectRepo
  defdelegate create_project(attrs \\ %{}), to: ProjectRepo
  defdelegate update_project(project, attrs \\ %{}), to: ProjectRepo
  defdelegate delete_project(project), to: ProjectRepo
  defdelegate change_project(project, attrs \\ %{}), to: ProjectRepo
end
