defmodule Lorito.Responses.Response do
  use Ash.Resource,
    otp_app: :lorito,
    domain: Lorito.Responses,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "responses"
    repo Lorito.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :status,
        :content_type,
        :body,
        :route,
        :delay,
        :placeholders,
        :headers,
        :template_id,
        :workspace_id
      ]

      validate present(:template_id), where: absent(:workspace_id)
      validate present(:workspace_id), where: absent(:template_id)

      argument :placeholders, {:array, :map}, default: []
      change set_attribute(:placeholders, arg(:placeholders))
      argument :headers, {:array, :map}, default: []
      change set_attribute(:headers, arg(:headers))

      change relate_actor(:user)
    end

    update :update do
      require_atomic? false

      accept [
        :status,
        :content_type,
        :body,
        :route,
        :delay,
        :placeholders,
        :headers
      ]

      argument :placeholders, {:array, :map}, default: []
      change set_attribute(:placeholders, arg(:placeholders))
      argument :headers, {:array, :map}, default: []
      change set_attribute(:headers, arg(:headers))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :integer, default: 200
    attribute :content_type, :string, default: "text/html"
    attribute :body, :string, default: "", constraints: [allow_empty?: true]
    attribute :route, :string, allow_nil?: false
    attribute :delay, :integer, default: 0

    attribute :placeholders, {:array, __MODULE__.Placeholder},
      public?: true,
      allow_nil?: false,
      default: []

    attribute :headers, {:array, __MODULE__.Header},
      public?: true,
      allow_nil?: false,
      default: []

    timestamps()
  end

  relationships do
    belongs_to :user, Lorito.Accounts.User
    belongs_to :workspace, Lorito.Workspaces.Workspace, attribute_type: :string
    belongs_to :template, Lorito.Templates.Template
  end
end
