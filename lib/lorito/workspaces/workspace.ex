defmodule Lorito.Workspaces.Workspace do
  use Ash.Resource,
    otp_app: :lorito,
    domain: Lorito.Workspaces,
    data_layer: AshPostgres.DataLayer,
    primary_read_warning?: false

  postgres do
    table "workspaces"
    repo Lorito.Repo
  end

  actions do
    defaults [:destroy]

    create :create do
      primary? true
      accept [:project_id, :template_id, :name, :path, :notifiable]

      change set_attribute(:rebindings, [])
      change relate_actor(:user)
    end

    read :read do
      primary? true
      prepare build(load: [:computed_path, :displayable_name])
    end

    read :get_workspace do
      get? true
      argument :id, :string, allow_nil?: false
      argument :project_id, :string, allow_nil?: false

      prepare build(
                load: [
                  :computed_path,
                  :displayable_name,
                  :rebound_routes,
                  :responses,
                  :logs,
                  :template,
                  :project
                ]
              )

      filter expr(id == ^arg(:id) and project_id == ^arg(:project_id))
    end

    read :get_workspace_by_path do
      get? true
      argument :path, :string, allow_nil?: false

      prepare build(
                load: [
                  :computed_path,
                  :displayable_name,
                  :rebound_routes,
                  :responses,
                  :logs,
                  :template,
                  :project
                ]
              )

      filter expr(path == ^arg(:path))
    end

    read :list_workspaces_by_project do
      argument :project_id, :string, allow_nil?: false

      prepare build(load: [:computed_path, :displayable_name])

      filter expr(project_id == ^arg(:project_id))
    end

    update :update do
      primary? true
      accept [:name, :notifiable, :path]
    end

    update :update_rebindings do
      require_atomic? false
      argument :rebindings, {:array, __MODULE__.Rebinding}, allow_nil?: true

      change set_attribute(:rebindings, arg(:rebindings))
    end
  end

  validations do
    validate match(:path, ~r|^[a-zA-Z0-9\._-]*$|)
  end

  attributes do
    attribute :id, :string,
      primary_key?: true,
      allow_nil?: false,
      default: fn -> Nanoid.generate(6) end

    attribute :name, :string, allow_nil?: true
    attribute :notifiable, :boolean, default: false
    attribute :path, :string, allow_nil?: true

    attribute :rebindings, {:array, __MODULE__.Rebinding},
      public?: true,
      allow_nil?: false,
      default: []

    timestamps()
  end

  relationships do
    belongs_to :user, Lorito.Accounts.User, allow_nil?: false
    belongs_to :project, Lorito.Projects.Project, attribute_type: :string, allow_nil?: false
    belongs_to :template, Lorito.Templates.Template, allow_nil?: true
    has_many :logs, Lorito.Logs.Log
    has_many :responses, Lorito.Responses.Response
  end

  calculations do
    calculate :computed_path,
              :string,
              expr(
                cond do
                  is_nil(path) -> "/#{project_id}/#{id}"
                  true -> path
                end
              )

    calculate :displayable_name,
              :string,
              expr(
                cond do
                  is_nil(name) -> id
                  name == "" -> id
                  true -> name
                end
              )

    calculate :rebound_routes,
              {:array, :string},
              fn records, _context ->
                Enum.map(records, fn record ->
                  record.rebindings
                  |> Enum.map(fn r -> r.route end)
                end)
              end
  end

  identities do
    identity :unique_id_per_project, [:id, :project_id]
    identity :unique_path, [:path]
  end
end
