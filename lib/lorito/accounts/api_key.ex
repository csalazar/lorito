defmodule Lorito.Accounts.ApiKey do
  use Ash.Resource,
    otp_app: :lorito,
    domain: Lorito.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "api_keys"
    repo Lorito.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :expires_at]
      change relate_actor(:user)

      change {AshAuthentication.Strategy.ApiKey.GenerateApiKey,
              prefix: :lorito, hash: :api_key_hash}
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type(:read) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:user)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :api_key_hash, :binary do
      allow_nil? false
      sensitive? true
    end

    attribute :name, :string do
      allow_nil? false
      constraints trim?: true, allow_empty?: false, max_length: 100
    end

    attribute :expires_at, :utc_datetime_usec
  end

  relationships do
    belongs_to :user, Lorito.Accounts.User
  end

  calculations do
    calculate :valid, :boolean, expr(is_nil(expires_at) or expires_at > now())
  end

  identities do
    identity :unique_api_key, [:api_key_hash]
  end
end
