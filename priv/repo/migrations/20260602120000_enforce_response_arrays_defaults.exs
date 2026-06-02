defmodule Lorito.Repo.Migrations.EnforceResponseArraysDefaults do
  use Ecto.Migration

  def up do
    execute("UPDATE responses SET headers = '[]'::jsonb WHERE headers IS NULL")
    execute("UPDATE responses SET placeholders = '[]'::jsonb WHERE placeholders IS NULL")

    execute("ALTER TABLE responses ALTER COLUMN headers SET DEFAULT '[]'::jsonb")
    execute("ALTER TABLE responses ALTER COLUMN placeholders SET DEFAULT '[]'::jsonb")

    execute("ALTER TABLE responses ALTER COLUMN headers SET NOT NULL")
    execute("ALTER TABLE responses ALTER COLUMN placeholders SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE responses ALTER COLUMN headers DROP NOT NULL")
    execute("ALTER TABLE responses ALTER COLUMN placeholders DROP NOT NULL")

    execute("ALTER TABLE responses ALTER COLUMN headers DROP DEFAULT")
    execute("ALTER TABLE responses ALTER COLUMN placeholders DROP DEFAULT")
  end
end
