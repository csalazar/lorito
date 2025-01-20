defmodule Lorito.Repo.Migrations.CreateWorkspaces do
  use Ecto.Migration

  def change do
    create table(:workspaces, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string
      add :rebindings, :map
      add :notifiable, :boolean, default: false
      add :path, :string, default: nil

      add :user_id, references(:users, on_delete: :delete_all, type: :uuid)
      add :project_id, references(:projects, on_delete: :delete_all, type: :string)
      add :template_id, references(:templates, on_delete: :delete_all, type: :uuid)

      timestamps()
    end

    create index(:workspaces, [:project_id])
  end
end
