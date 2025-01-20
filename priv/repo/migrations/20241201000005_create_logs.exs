defmodule Lorito.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :method, :string
      add :ip, :string
      add :url, :text
      add :headers, {:array, {:array, :text}}, default: []
      add :body, :text
      add :params, :map

      add :workspace_id, references(:workspaces, on_delete: :delete_all, type: :string)
      add :project_id, references(:projects, on_delete: :delete_all, type: :string)

      timestamps()
    end
  end
end
