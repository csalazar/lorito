defmodule Lorito.Templates.Template do
  use Ash.Resource, otp_app: :lorito, domain: Lorito.Templates, data_layer: AshPostgres.DataLayer

  postgres do
    table "templates"
    repo Lorito.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :get_template_by_id do
      prepare build(load: [:responses])
    end

    create :create do
      primary? true
      accept [:name]

      argument :copy_payloads, {:array, :map}, default: []
      change set_attribute(:copy_payloads, arg(:copy_payloads))

      change relate_actor(:user)
    end

    update :update do
      require_atomic? false
      primary? true
      accept [:name]

      argument :copy_payloads, {:array, :map}, default: []
      change set_attribute(:copy_payloads, arg(:copy_payloads))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :copy_payloads, {:array, __MODULE__.CopyPayload},
      public?: true,
      allow_nil?: false,
      default: []

    timestamps()
  end

  relationships do
    belongs_to :user, Lorito.Accounts.User
    has_many :responses, Lorito.Responses.Response
  end
end
