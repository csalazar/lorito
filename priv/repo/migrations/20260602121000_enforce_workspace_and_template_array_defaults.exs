defmodule Lorito.Repo.Migrations.EnforceWorkspaceAndTemplateArrayDefaults do
  use Ecto.Migration

  def up do
    execute("UPDATE workspaces SET rebindings = '[]'::jsonb WHERE rebindings IS NULL")
    execute("UPDATE templates SET copy_payloads = '[]'::jsonb WHERE copy_payloads IS NULL")

    execute("ALTER TABLE workspaces ALTER COLUMN rebindings SET DEFAULT '[]'::jsonb")
    execute("ALTER TABLE templates ALTER COLUMN copy_payloads SET DEFAULT '[]'::jsonb")

    execute("ALTER TABLE workspaces ALTER COLUMN rebindings SET NOT NULL")
    execute("ALTER TABLE templates ALTER COLUMN copy_payloads SET NOT NULL")
  end

  def down do
    execute("ALTER TABLE workspaces ALTER COLUMN rebindings DROP NOT NULL")
    execute("ALTER TABLE templates ALTER COLUMN copy_payloads DROP NOT NULL")

    execute("ALTER TABLE workspaces ALTER COLUMN rebindings DROP DEFAULT")
    execute("ALTER TABLE templates ALTER COLUMN copy_payloads DROP DEFAULT")
  end
end
