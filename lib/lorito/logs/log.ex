require Ash.Query

defmodule Lorito.Logs.Log do
  use Ash.Resource,
    otp_app: :lorito,
    domain: Lorito.Logs,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub],
    primary_read_warning?: false

  postgres do
    table "all_logs"
    repo Lorito.Repo
  end

  actions do
    read :read do
      primary? true
      prepare build(load: [:project, :workspace, :implementation])
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
                load: [:project, :workspace, :implementation],
                limit: 100,
                sort: [inserted_at: :desc]
              )
    end

    action :delete_log do
      argument :log, :struct, allow_nil?: false

      run fn input, _context ->
        log = input.arguments.log

        Lorito.Logs.Helpers.log_protocol_to_module(log.protocol)
        |> Ash.Query.filter(id == ^log.id)
        |> Ash.read_one!()
        |> Ash.destroy!()

        :ok
      end
    end

    action :delete_logs_by_ip do
      argument :ip, :string, allow_nil?: false

      run fn input, _context ->
        [Lorito.Logs.HTTP, Lorito.Logs.DNS]
        |> Enum.each(fn resource ->
          {:ok, _} =
            resource
            |> Ash.Query.for_read(:read)
            |> Ash.Query.filter(ip == ^input.arguments.ip)
            |> Lorito.Logs.Helpers.bulk_destroy()
        end)

        :ok
      end
    end

    action :delete_logs_by_type do
      argument :type, :atom, allow_nil?: false

      run fn input, _context ->
        type = input.arguments.type

        case type do
          :catch_all ->
            [Lorito.Logs.HTTP, Lorito.Logs.DNS]
            |> Enum.each(fn resource ->
              {:ok, _} =
                resource
                |> Ash.Query.for_read(:read)
                |> Ash.Query.filter(is_nil(project_id))
                |> Lorito.Logs.Helpers.bulk_destroy()
            end)

            :ok
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :protocol, :atom, constraints: [one_of: [:http, :dns]]

    timestamps()
  end

  relationships do
    belongs_to :workspace, Lorito.Workspaces.Workspace, attribute_type: :string, allow_nil?: true
    belongs_to :project, Lorito.Projects.Project, attribute_type: :string, allow_nil?: true

    has_one :http_details, Lorito.Logs.HTTP do
      source_attribute :id
      destination_attribute :id
    end

    has_one :dns_details, Lorito.Logs.DNS do
      source_attribute :id
      destination_attribute :id
    end
  end

  calculations do
    calculate :implementation, __MODULE__.LogImplementation, __MODULE__.GetLogImplementation do
      allow_nil? false
    end
  end
end
