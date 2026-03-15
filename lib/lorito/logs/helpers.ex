defmodule Lorito.Logs.Helpers do
  def log_protocol_to_module(:http), do: Lorito.Logs.HTTP
  def log_protocol_to_module(:dns), do: Lorito.Logs.DNS

  def bulk_destroy(query) do
    case Ash.bulk_destroy(query, :destroy, %{}, return_records?: true) do
      %Ash.BulkResult{status: :success, records: records} ->
        {:ok, records}

      %Ash.BulkResult{status: :error, errors: reason} ->
        {:error, reason}
    end
  end

  defp is_notifiable?(log) do
    (log.project && log.project.notifiable) ||
      (log.workspace && log.workspace.notifiable)
  end

  def notify_integrations(_changeset, record, _ctx) do
    log =
      record
      |> Ash.load!([:project, :workspace])

    if is_notifiable?(log) do
      Lorito.Logs.list_integrations!()
      |> Enum.each(fn integration ->
        Lorito.Logs.send_integration_notification(integration, log)
      end)
    end

    {:ok, record}
  end
end
