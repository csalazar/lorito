defmodule Lorito.Logs do
  alias Lorito.Logs.Log
  alias Lorito.Logs.PubSub, as: LogsPubSub
  alias Lorito.Logs.LogsRepo
  alias Lorito.Utils.RequestParser

  defdelegate list_logs(filters \\ %{}), to: LogsRepo
  defdelegate get_log!(id), to: LogsRepo
  defdelegate update_log(log, attrs \\ %{}), to: LogsRepo
  defdelegate delete_log(log), to: LogsRepo
  defdelegate delete_logs(criteria), to: LogsRepo
  defdelegate change_log(log, attrs \\ %{}), to: LogsRepo

  @doc """
  Do nothing if it's a catch-all log.
  Send integration notification if the project or workspace has notifications enabled.
  """
  def dispatch_notifications({:error, %Ecto.Changeset{}} = error), do: error

  def dispatch_notifications({:ok, %Log{project_id: nil, workspace_id: nil} = log}),
    do: {:ok, log}

  def dispatch_notifications({:ok, %Log{} = log}) do
    log = LogsRepo.get_log!(log.id)

    if log.project.notifiable or log.workspace.notifiable do
      Lorito.Integrations.dispatch_notifications(log)
    end

    {:ok, log}
  end

  def create_log(attrs \\ %{}) do
    LogsRepo.create_log(attrs)
    |> LogsPubSub.notify_subscribers([:log, :created])
    |> dispatch_notifications()
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
