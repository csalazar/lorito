defmodule Lorito.Workspaces.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: {Nanoid, :generate, [6]}}
  @foreign_key_type :string
  schema "workspaces" do
    field :name, :string
    field :notifiable, :boolean, default: false
    field :path, :string

    belongs_to(:user, Lorito.Accounts.User, type: :binary_id)
    belongs_to(:project, Lorito.Projects.Project, type: :string)
    belongs_to(:template, Lorito.Templates.Template, type: :binary_id)

    has_many :logs, Lorito.Logs.Log
    has_many :responses, Lorito.Responses.Response

    embeds_many :rebindings, Rebinding, on_replace: :delete do
      field :route, :string
      field :responses, {:array, :binary_id}
      field :activations, {:array, :integer}
      field :strategy, :string
      field :icon, :string
    end

    timestamps()
  end

  @doc false
  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :path, :notifiable])
    |> validate_format(:path, ~r|^[a-zA-Z0-9\._-]*$|)
    |> cast_embed(:rebindings, with: &rebinding_changeset/2)
  end

  def rebinding_changeset(rebinding, attrs) do
    rebinding
    |> cast(attrs, [:route, :icon, :responses, :activations, :strategy])
  end

  def changeset_update(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :path, :notifiable])
    |> validate_format(:path, ~r|^[a-zA-Z0-9\._-]*$|)
    |> cast_embed(:rebindings, with: &rebinding_changeset/2)
  end

  def get_path(%__MODULE__{} = workspace) do
    case workspace.path do
      nil -> "/#{workspace.project_id}/#{workspace.id}"
      custom_path -> custom_path
    end
  end

  def get_displayable_name(%__MODULE__{} = workspace) do
    case workspace.name do
      nil -> workspace.id
      "" -> workspace.id
      name -> name
    end
  end
end
