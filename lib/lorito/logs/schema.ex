defmodule Lorito.Logs.Log do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "logs" do
    field :ip, :string
    field :method, :string
    field :url, :string
    field :headers, {:array, {:array, :string}}, default: []
    field :body, :string, default: ""
    field :params, :map, default: %{}
    field :host, :string, virtual: true

    belongs_to(:workspace, Lorito.Workspaces.Workspace, type: :string)
    belongs_to(:project, Lorito.Projects.Project, type: :string)

    timestamps()
  end

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, [:method, :ip, :url, :headers, :body, :workspace_id, :project_id, :params])
    |> validate_required([:method, :ip, :url, :headers])
  end

  defp get_host(headers) do
    headers
    |> Enum.find(fn [header, _value] -> header == "host" end)
    |> case do
      [_, host] ->
        host

      nil ->
        ""
    end
  end

  def populate_host_field(%__MODULE__{} = log) do
    host = log.headers |> get_host()
    %{log | host: host}
  end
end
