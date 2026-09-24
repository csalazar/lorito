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

    action :get_settings, :map do
      run fn _input, context ->
        opts = Ash.Scope.to_opts(context, not_found_error?: true)

        with {:ok, setting} <- Ash.read_one(__MODULE__, opts) do
          {:ok, setting.data}
        end
      end
    end

    update :update do
      primary? true
      accept [:data]
      require_atomic? false

      change fn changeset, _ ->
        data = Ash.Changeset.get_attribute(changeset, :data)

        if is_map(data) do
          normalized =
            data
            |> normalize_bool_key("dns_enabled")
            |> normalize_bool_key("scoped_mode")

          Ash.Changeset.change_attribute(changeset, :data, normalized)
        else
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

  defp normalize_bool_key(data, key) do
    case Map.fetch(data, key) do
      {:ok, value} -> Map.put(data, key, value in [true, "true"])
      :error -> data
    end
  end
end
