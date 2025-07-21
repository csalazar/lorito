defmodule Lorito.Repo.Migrations.AddSubdomainToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :subdomain, :string
    end

    create unique_index(:projects, [:subdomain])
  end
end
