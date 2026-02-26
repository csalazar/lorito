defmodule Lorito.Logs.Integrations.Discord do
  alias Lorito.Logs.{Integration, Log}

  def send_probe(%Integration{} = integration) do
    Lorito.Utils.HttpClient.post(integration.webhook_url, %{content: "hola from lorito"})
  end

  def send_notification(%Integration{} = integration, %Log{} = log) do
    title =
      case log.workspace do
        nil -> log.project.name
        _ -> "#{log.project.name} - #{log.workspace.displayable_name}"
      end

    embed = %{
      title: title,
      description: "#{LoritoWeb.Endpoint.url()}/_lorito/logs/#{log.id}",
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

    Lorito.Utils.HttpClient.post(integration.webhook_url, %{
      content: "New request received",
      embeds: [embed]
    })
  end
end
