defmodule Lorito.Logs do
  alias Lorito.Utils.RequestParser

  use Ash.Domain,
    otp_app: :lorito,
    extensions: [AshPhoenix]

  resources do
    resource Lorito.Logs.Log do
      define :list_logs, action: :list_logs
      define :get_log_by_id, action: :read, get_by: [:id]
      define :create_log, action: :create
      define :delete_log, action: :destroy
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
