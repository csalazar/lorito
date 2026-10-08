defmodule Lorito.Repo.Migrations.AddHttpLogBodyCaptureMetadata do
  use Ecto.Migration

  def change do
    alter table(:http_logs) do
      add :body_encoding, :text, null: false, default: "utf-8"
    end
  end
end
