defmodule Lorito.Settings.Setting do
  use Ash.Resource,
    otp_app: :lorito,
    domain: Lorito.Settings,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "settings"
    repo Lorito.Repo
  end

  actions do
    defaults [:read]

    update :update do
      primary? true
      accept [:data]
      require_atomic? false

      change fn changeset, _ ->
        case Ash.Changeset.get_attribute(changeset, :data) do
          %{"dns_enabled" => dns_enabled} = data ->
            normalized = Map.put(data, "dns_enabled", dns_enabled in [true, "true"])
            Ash.Changeset.change_attribute(changeset, :data, normalized)

          _ ->
            changeset
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :data, :map, allow_nil?: false, default: %{}
    timestamps()
  end
end
