defmodule Lorito.Projects.Project do
  use Ash.Resource, otp_app: :lorito, domain: Lorito.Projects, data_layer: AshPostgres.DataLayer

  postgres do
    table "projects"
    repo Lorito.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :notifiable, :subdomain]
      change relate_actor(:user)
    end

    update :update do
      primary? true
      accept [:name, :notifiable, :subdomain]
    end
  end

  attributes do
    attribute :id, :string,
      primary_key?: true,
      allow_nil?: false,
      default: fn -> Nanoid.generate(6) end

    attribute :name, :string do
      allow_nil? false
    end

    attribute :notifiable, :boolean, default: false
    attribute :subdomain, :string
    timestamps()
  end

  relationships do
    belongs_to :user, Lorito.Accounts.User
    has_many :workspaces, Lorito.Workspaces.Workspace
  end

  identities do
    identity :subdomain, [:subdomain]
  end
end
