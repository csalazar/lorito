defmodule Lorito.Templates.Template do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "templates" do
    field :name, :string

    belongs_to(:user, Lorito.Accounts.User, type: :binary_id)
    has_many :responses, Lorito.Responses.Response

    embeds_many :copy_payloads, CopyPayload, on_replace: :delete do
      field :name, :string
      field :value, :string
    end

    timestamps()
  end

  def copy_payload_changeset(copy_payload, attrs) do
    copy_payload
    |> cast(attrs, [:name, :value])
  end

  @default_copy_payloads %{
    _unused_copy_payloads_drop: [""],
    _unused_copy_payloads_sort: [""],
    copy_payloads: %{
      "0" => %{"_persistent_id" => "0", "name" => "url", "value" => "{{ workspace_url }}"}
    },
    copy_payloads_drop: [""],
    copy_payloads_sort: ["0"]
  }

  @doc false
  def changeset(template, attrs) do
    default_values =
      if Enum.count(template.copy_payloads) > 0 or Map.has_key?(attrs, "copy_payloads") do
        %{}
      else
        @default_copy_payloads
      end

    attrs = Map.merge(attrs, default_values)

    template
    |> cast(attrs, [:name])
    |> cast_embed(:copy_payloads,
      with: &copy_payload_changeset/2,
      sort_param: :copy_payloads_sort,
      drop_param: :copy_payloads_drop
    )
    |> validate_required([:name])
  end

  def changeset_update_responses(template, responses) do
    template
    |> cast(%{}, [])
    |> put_assoc(:responses, responses)
  end

  def put_template(%Ecto.Changeset{} = changeset, nil) do
    changeset
  end

  def put_template(%Ecto.Changeset{} = changeset, %__MODULE__{} = template) do
    put_assoc(changeset, :template, template)
  end
end
