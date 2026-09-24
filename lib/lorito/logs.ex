defmodule Lorito.Logs do
  alias Lorito.Utils.RequestParser

  use Ash.Domain,
    otp_app: :lorito,
    extensions: [AshPhoenix, AshAi]

  tools do
    tool :delete_log, Lorito.Logs.Log, :delete_log_by_id do
      description "Permanently delete one HTTP or DNS log by log_id, using an ID returned by list_logs. Returns true on success."
    end

    tool :list_logs, Lorito.Logs.Log, :list_logs do
      description """
      List recent logs.
      Provide project_id to list logs for a project.
      Provide both project_id and workspace_id to list logs for a workspace within a project.
      Provide inserted_after as an ISO 8601 UTC datetime to list logs created at or after that time.

      Omit filters to list recent logs globally.
      """

      load [
        :project,
        :workspace,
        :implementation,
        http_details: [:host, :ip, :method, :url],
        dns_details: [:host]
      ]
    end
  end

  resources do
    resource Lorito.Logs.Log do
      define :list_logs, action: :list_logs
      define :get_log_by_id, action: :read, get_by: [:id]
      define :delete_log, action: :delete_log, args: [:log]
      define :delete_log_by_id, action: :delete_log_by_id, args: [:log_id]
      define :delete_logs_by_ip, action: :delete_logs_by_ip, args: [:ip]
      define :delete_logs_by_type, action: :delete_logs_by_type, args: [:type]
    end

    resource Lorito.Logs.Integration do
      define :list_integrations, action: :read
      define :get_integration_by_id, action: :read, get_by: [:id]
      define :create_integration, action: :create
      define :update_integration, action: :update
      define :delete_integration, action: :destroy

      define :send_integration_probe, action: :send_probe, args: [:integration]

      define :send_integration_notification,
        action: :send_notification,
        args: [:integration, :log]
    end

    resource Lorito.Logs.HTTP do
      define :create_http_log, action: :create
    end

    resource Lorito.Logs.DNS do
      define :create_dns_log, action: :create
    end
  end

  def gather_log_attributes(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)

    %{
      ip: RequestParser.get_ip(conn),
      method: conn.method,
      url: RequestParser.get_url(conn),
      headers: RequestParser.get_headers(conn),
      body: body,
      params: RequestParser.get_params(conn)
    }
  end
end
