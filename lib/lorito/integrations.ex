defmodule Lorito.Integrations do
  @moduledoc """
  The Integrations context.
  """

  alias Lorito.Integrations.Integration
  alias Lorito.Logs.Log
  alias Lorito.Workspaces.Workspace

  alias Lorito.Integrations.IntegrationRepo

  defdelegate list_integrations(filters \\ %{}), to: IntegrationRepo
  defdelegate get_integration!(id), to: IntegrationRepo
  defdelegate create_integration(attrs \\ %{}), to: IntegrationRepo
  defdelegate update_integration(integration, attrs \\ %{}), to: IntegrationRepo
  defdelegate delete_integration(integration), to: IntegrationRepo
  defdelegate change_integration(integration, attrs \\ %{}), to: IntegrationRepo

  def send_probe(%Integration{type: :discord} = integration) do
    Lorito.Utils.HttpClient.post(integration.webhook_url, %{content: "hola from lorito"})
  end

  def dispatch_notifications(%Log{} = log) do
    list_integrations()
    |> Enum.map(&send_notification(&1, log))
  end

  def send_notification(%Integration{type: :discord} = integration, %Log{} = log) do
    embed = %{
      title: "#{log.project.name} - #{Workspace.get_displayable_name(log.workspace)}",
      description: "#{LoritoWeb.Endpoint.url()}/logs/#{log.id}",
      color: 7_506_394,
      fields: [
        %{
          name: "IP",
          value: log.ip
        },
        %{
          name: "Method",
          value: log.method
        },
        %{
          name: "URL",
          value: log.url
        }
      ]
    }

    {:ok, _} =
      Lorito.Utils.HttpClient.post(integration.webhook_url, %{
        content: "New request received",
        embeds: [embed]
      })
  end
end
