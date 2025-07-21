defmodule Lorito.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: {Nanoid, :generate, [6]}}
  @foreign_key_type :string
  schema "projects" do
    field :name, :string
    field :notifiable, :boolean, default: false
    field :subdomain, :string

    belongs_to(:user, Lorito.Accounts.User, type: :binary_id)
    has_many :workspaces, Lorito.Workspaces.Workspace

    timestamps()
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :notifiable, :subdomain])
    |> validate_required([:name])
  end

  def put_project(%Ecto.Changeset{} = changeset, nil) do
    changeset
  end

  def put_project(%Ecto.Changeset{} = changeset, %__MODULE__{} = project) do
    put_assoc(changeset, :project, project)
  end
end
