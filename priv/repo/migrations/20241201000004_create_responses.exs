defmodule Lorito.Repo.Migrations.CreateResponses do
  use Ecto.Migration

  def change do
    create table(:responses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :route, :string
      add :status, :integer
      add :headers, :map
      add :body, :text
      add :placeholders, :map
      add :delay, :integer, default: 0
      add :content_type, :string, default: "text/html"

      add :user_id, references(:users, on_delete: :delete_all, type: :uuid)
      add :workspace_id, references(:workspaces, on_delete: :delete_all, type: :string)
      add :template_id, references(:templates, on_delete: :delete_all, type: :uuid)

      timestamps()
    end
  end
end
