defmodule Lorito.Projects do
  use Ash.Domain,
    otp_app: :lorito,
    extensions: [AshPhoenix, AshAi]

  tools do
    tool :list_projects, Lorito.Projects.Project, :read do
      description "List all projects. Don't provide any arguments."
      load [:id, :name, :subdomain, :notifiable]
    end

    tool :create_project, Lorito.Projects.Project, :create do
      load [:id, :name, :subdomain, :notifiable]

      description "Create a new project"
    end

    tool :get_project_by_name, Lorito.Projects.Project, :get_by_name do
      description "Get a single project by its name"
      load [:id, :name, :subdomain, :notifiable]
    end
  end

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
