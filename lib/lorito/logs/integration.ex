defmodule Lorito.Logs.Integration do
  use Ash.Resource, otp_app: :lorito, domain: Lorito.Logs, data_layer: AshPostgres.DataLayer

  @integration_modules %{
    discord: Lorito.Logs.Integrations.Discord
  }

  postgres do
    table "integrations"
    repo Lorito.Repo
  end

  actions do
    defaults [:read, :update, :destroy]
    default_accept [:type, :webhook_url]

    create :create do
      change relate_actor(:user)
    end

    action :send_probe, :map do
      argument :integration,
        type: :struct,
        allow_nil?: false,
        constraints: [instance_of: __MODULE__]

      run fn input, _ ->
        integration = input.arguments.integration
        module = Map.fetch!(@integration_modules, String.to_existing_atom(integration.type))

        case module.send_probe(integration) do
          {:ok, response} -> {:ok, %{status: response.status, body: response.body}}
          {:error, reason} -> {:error, reason}
        end
      end
    end

    action :send_notification, :map do
      argument :integration,
        type: :struct,
        allow_nil?: false,
        constraints: [instance_of: __MODULE__]

      argument :log,
        type: :struct,
        allow_nil?: false,
        constraints: [instance_of: Lorito.Logs.Log]

      run fn input, _ ->
        integration = input.arguments.integration
        log = input.arguments.log
        module = Map.fetch!(@integration_modules, String.to_existing_atom(integration.type))

        case module.send_notification(integration, log) do
          {:ok, response} -> {:ok, %{status: response.status, body: response.body}}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end

  validations do
    validate one_of(:type, [:discord])

    validate match(:webhook_url, ~r/^https:\/\/discord\.com\/api\/webhooks\//) do
      where [attribute_equals(:type, :discord)]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :type, :string, allow_nil?: false
    attribute :webhook_url, :string, allow_nil?: false
    timestamps()
  end

  relationships do
    belongs_to :user, Lorito.Accounts.User
  end
end
