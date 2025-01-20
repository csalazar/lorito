defmodule Lorito.Workspaces do
  alias Lorito.Workspaces.WorkspaceRepo
  alias Lorito.Workspaces.Rebindings

  defdelegate list_workspaces(filters), to: WorkspaceRepo
  defdelegate get_workspace!(id), to: WorkspaceRepo
  defdelegate get_workspace(filters), to: WorkspaceRepo
  defdelegate create_workspace(attrs), to: WorkspaceRepo
  defdelegate update_workspace(workspace, attrs \\ %{}), to: WorkspaceRepo
  defdelegate delete_workspace(workspace), to: WorkspaceRepo
  defdelegate change_workspace(workspace, attrs \\ %{}), to: WorkspaceRepo

  defdelegate promote_response_to_rebinding(workspace, response), to: Rebindings
  defdelegate demote_response_from_rebindings(workspace, route), to: Rebindings
  defdelegate is_response_active?(rebinding, response), to: Rebindings
end
