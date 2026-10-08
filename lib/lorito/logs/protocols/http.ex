require Ash.Query

defmodule Lorito.Logs.HTTP do
  use Ash.Resource,
    otp_app: :lorito,
    domain: Lorito.Logs,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub],
    primary_read_warning?: false

  postgres do
    table "http_logs"
    repo Lorito.Repo

    custom_indexes do
      index [:inserted_at, :id]
      index [:workspace_id, :inserted_at, :id]
    end
  end

  actions do
    defaults [:destroy]

    default_accept [
      :ip,
      :method,
      :url,
      :headers,
      :body,
      :body_encoding,
      :error,
      :params,
      :workspace_id,
      :project_id
    ]

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
    attribute :ip, :string, allow_nil?: false
    attribute :method, :string, allow_nil?: false
    attribute :url, :string, allow_nil?: false
    attribute :headers, {:array, {:array, :string}}, default: []
    attribute :body, :string, default: "", constraints: [trim?: false, allow_empty?: true]
    attribute :body_encoding, :string, allow_nil?: false, default: "utf-8"
    attribute :error, :string
    attribute :params, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :workspace, Lorito.Workspaces.Workspace, attribute_type: :string
    belongs_to :project, Lorito.Projects.Project, attribute_type: :string
  end

  calculations do
    calculate :host, :string do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          record.headers
          |> Enum.find(fn [header, _value] -> header == "host" end)
          |> case do
            [_, host] ->
              host

            nil ->
              ""
          end
        end)
      end
    end
  end
end
