defmodule Lorito.Repo.Migrations.AddErrorToHttpLogs do
  use Ecto.Migration

  def change do
    alter table(:http_logs) do
      add :error, :text
    end
  end
end
