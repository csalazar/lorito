defmodule Lorito.Responses.Response do
  use Ecto.Schema
  import Ecto.Changeset

  @available_placeholders ["🍉", "🥝", "🍊", "🍏", "🍇", "🍋", "🍌"]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "responses" do
    field :status, :integer, default: 200
    field :content_type, :string, default: "text/html"
    field :body, :string, default: ""
    field :route, :string
    field :delay, :integer, default: 0

    belongs_to(:user, Lorito.Accounts.User, type: :binary_id)
    belongs_to(:workspace, Lorito.Workspaces.Workspace, type: :string)
    belongs_to(:template, Lorito.Templates.Template, type: :binary_id)

    embeds_many :headers, Header, on_replace: :delete do
      field :name, :string
      field :value, :string
    end

    embeds_many :placeholders, Placeholder, on_replace: :delete do
      field :icon, :string
      field :value, :string
    end

    timestamps()
  end

  def header_changeset(header, attrs) do
    header
    |> cast(attrs, [:name, :value])
  end

  def placeholder_changeset(placeholder, attrs, index) do
    attrs =
      if attrs == %{} do
        icon = @available_placeholders |> Enum.at(index)
        %{icon: icon}
      else
        attrs
      end

    placeholder
    |> cast(attrs, [:icon, :value])
  end

  @doc false
  def changeset(response, attrs) do
    response
    |> cast(attrs, [:route, :delay, :status, :body, :content_type, :workspace_id, :template_id])
    |> validate_required([:route, :status])
    |> cast_embed(:headers,
      with: &header_changeset/2,
      sort_param: :headers_sort,
      drop_param: :headers_drop
    )
    |> cast_embed(:placeholders,
      with: &placeholder_changeset/3,
      sort_param: :placeholders_sort,
      drop_param: :placeholders_drop
    )
  end
end
