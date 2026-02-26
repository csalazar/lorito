require Ash.Query

defmodule Lorito.Logs.Log do
  use Ash.Resource,
    otp_app: :lorito,
    domain: Lorito.Logs,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub],
    primary_read_warning?: false

  postgres do
    table "logs"
    repo Lorito.Repo
  end

  actions do
    defaults [:destroy]
    default_accept [:ip, :method, :url, :headers, :body, :params, :workspace_id, :project_id]

    read :read do
      primary? true
      prepare build(load: [:project, :workspace, :host])
    end

    read :list_logs do
      argument :scoped_logs, :boolean, default: false

      filter expr(
               if ^arg(:scoped_logs) != false do
                 not is_nil(project_id)
               else
                 true
               end
             )

      prepare build(
                load: [:project, :workspace, :host],
                limit: 100,
                sort: [inserted_at: :desc]
              )
    end

    create :create do
      primary? true

      change after_action(fn changeset, record, _ctx ->
               log =
                 record
                 |> Ash.load!([:project, :workspace])

               if __MODULE__.is_notifiable?(log) do
                 Lorito.Logs.list_integrations!()
                 |> Enum.each(fn integration ->
                   Lorito.Logs.send_integration_notification(integration, log)
                 end)
               end

               {:ok, record}
             end)
    end

    action :delete_logs_by_ip, :term do
      argument :ip, :string, allow_nil?: false

      run fn input, _context ->
        __MODULE__
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(ip == ^input.arguments.ip)
        |> bulk_destroy()
      end
    end

    action :delete_logs_by_type, :term do
      argument :type, :string, allow_nil?: false

      run fn input, _context ->
        type = input.arguments.type

        query =
          __MODULE__
          |> Ash.Query.for_read(:read)
          |> Ash.Query.filter(is_nil(project_id))
          |> bulk_destroy()
      end
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
    attribute :body, :string, default: ""
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

  def bulk_destroy(query) do
    case Ash.bulk_destroy(query, :destroy, %{}, return_records?: true) do
      %Ash.BulkResult{status: :success, records: records} ->
        {:ok, records}

      %Ash.BulkResult{status: :error, errors: reason} ->
        {:error, reason}
    end
  end

  def is_notifiable?(log) do
    (log.project && log.project.notifiable) ||
      (log.workspace && log.workspace.notifiable)
  end
end
