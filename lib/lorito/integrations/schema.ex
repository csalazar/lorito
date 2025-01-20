defmodule Lorito.Integrations.Integration do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "integrations" do
    field :type, Ecto.Enum, values: [:discord]
    field :webhook_url, :string

    belongs_to(:user, Lorito.Accounts.User, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [:type, :webhook_url])
    |> validate_required([:type, :webhook_url])
    |> validate_webhook_url()
  end

  defp validate_webhook_url(changeset) do
    case get_field(changeset, :type) do
      :discord ->
        validate_format(changeset, :webhook_url, ~r/^https:\/\/discord\.com\/api\/webhooks\//,
          message: "must be a valid Discord webhook URL"
        )

      _ ->
        changeset
    end
  end
end
