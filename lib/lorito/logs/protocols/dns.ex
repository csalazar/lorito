defmodule Lorito.Logs.DNS do
  use Ash.Resource,
    otp_app: :lorito,
    domain: Lorito.Logs,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub],
    primary_read_warning?: false

  postgres do
    table "dns_logs"
    repo Lorito.Repo
  end

  actions do
    defaults [:destroy]
    default_accept [:query_name, :record_type, :ip, :workspace_id, :project_id]

    create :create do
      primary? true
      change after_action(&Lorito.Logs.Helpers.notify_integrations/3)
    end

    read :read do
      primary? true
      prepare build(load: [:project, :workspace, :host])
    end
  end

  pub_sub do
    module LoritoWeb.Endpoint

    prefix "log"
    publish :create, ["created"]
    publish :create, [[:workspace_id], "created"]
  end

  attributes do
    uuid_primary_key :id
    attribute :query_name, :string, allow_nil?: false
    attribute :record_type, :string, allow_nil?: false
    attribute :ip, :string, allow_nil?: false

    timestamps()
  end

  relationships do
    belongs_to :workspace, Lorito.Workspaces.Workspace, attribute_type: :string, allow_nil?: true
    belongs_to :project, Lorito.Projects.Project, attribute_type: :string, allow_nil?: true
  end

  calculations do
    calculate :host, :string do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          record.query_name
        end)
      end
    end
  end
end
