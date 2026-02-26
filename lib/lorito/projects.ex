defmodule Lorito.Projects do
  use Ash.Domain,
    otp_app: :lorito,
    extensions: [AshPhoenix]

  resources do
    resource Lorito.Projects.Project do
      define :list_projects, action: :read
      define :create_project, action: :create
      define :delete_project, action: :destroy
      define :update_project, action: :update
      define :get_project_by_id, action: :read, get_by: [:id]
      define :get_project_by_subdomain, action: :read, get_by: [:subdomain]
    end
  end
end
