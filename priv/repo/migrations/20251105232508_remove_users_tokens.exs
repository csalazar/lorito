defmodule Lorito.Repo.Migrations.RemoveUsersTokens do
  use Ecto.Migration

  def change do
    drop table(:users_tokens)
  end
end
