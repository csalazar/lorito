defmodule Lorito.Logs.Integrations.Discord do
  alias Lorito.Logs.{Integration, HTTP, DNS}

  def send_probe(%Integration{} = integration) do
    {:ok, _} = Req.post(integration.webhook_url, json: %{content: "hola from lorito"})
  end

  def send_notification(%Integration{} = integration, %HTTP{} = log) do
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

    Req.post(integration.webhook_url,
      json: %{
        content: "New HTTP request received",
        embeds: [embed]
      }
    )
  end

  def send_notification(%Integration{} = integration, %DNS{} = log) do
    title = log.project.name

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
          name: "Record",
          value: log.record_type
        },
        %{
          name: "FQDN",
          value: log.query_name
        }
      ]
    }

    Req.post(integration.webhook_url,
      json: %{
        content: "New DNS request received",
        embeds: [embed]
      }
    )
  end
end
