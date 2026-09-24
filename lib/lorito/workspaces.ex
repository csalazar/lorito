alias Lorito.Workspaces.Rebindings

defmodule Lorito.Workspaces do
  use Ash.Domain,
    otp_app: :lorito,
    extensions: [AshPhoenix, AshAi]

  forms do
    form(:create_workspace, args: [:project_id])
  end

  tools do
    tool :list_workspaces_by_project, Lorito.Workspaces.Workspace, :list_workspaces_by_project do
      description "List all workspaces for a given project.
      `project_id` can be retrieved from tool `get_project_by_name`.
      "
      load [:id, :name, :path, :full_url]
    end

    tool :create_workspace, Lorito.Workspaces.Workspace, :create do
      load [:id, :name, :project_id, :path]

      description "Create a new workspace for a given project name.
      `project_id` can be retrieved from tool `get_project_by_name`.
      If path, template or notifiable is not provided, don't add it to the request."
    end
  end

  resources do
    resource Lorito.Workspaces.Workspace do
      define :get_workspace, action: :get_workspace
      define :get_workspace_by_path, action: :get_workspace_by_path, args: [:path]
      define :list_workspaces_by_project, action: :list_workspaces_by_project, args: [:project_id]
      define :create_workspace, action: :create
      define :delete_workspace, action: :destroy
      define :update_workspace, action: :update
      define :update_rebindings, action: :update_rebindings, args: [:rebindings]

      defdelegate promote_response_to_rebinding(workspace, response), to: Rebindings
      defdelegate demote_response_from_rebindings(workspace, route), to: Rebindings
      defdelegate is_response_active?(rebinding, response), to: Rebindings
    end
  end
end
