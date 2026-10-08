defmodule LoritoWeb.LogLive.Show do
  use LoritoWeb, :live_view

  alias Lorito.Logs

  @preview_bytes 64_000

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, %{assigns: %{live_action: live_action}} = socket) do
    log = Logs.get_log_by_id!(id)
    record = log.implementation.value
    body = if log.protocol == :http, do: record.body || "", else: ""
    preview = binary_part(body, 0, min(byte_size(body), @preview_bytes))
    preview = trim_incomplete_utf8(preview)

    uploads =
      if log.protocol == :http do
        case Lorito.Utils.UploadRecovery.list(record) do
          {:ok, files} -> files
          _ -> []
        end
      else
        []
      end

    {:noreply,
     socket
     |> assign(:page_title, "Show Log")
     |> assign(:log, if(log.protocol == :http, do: %{record | body: ""}, else: record))
     |> assign(:body_preview, preview)
     |> assign(:recovered_files, uploads)
     |> assign(:body_size, payload_size(body, Map.get(record, :body_encoding)))
     |> assign(:body_truncated, byte_size(preview) < byte_size(body))
     |> assign(:protocol, log.protocol)
     |> assign(:live_action, live_action)}
  end

  defp payload_size(body, "base64") do
    padding =
      cond do
        String.ends_with?(body, "==") -> 2
        String.ends_with?(body, "=") -> 1
        true -> 0
      end

    div(byte_size(body) * 3, 4) - padding
  end

  defp payload_size(body, _encoding), do: byte_size(body)

  defp trim_incomplete_utf8(""), do: ""

  defp trim_incomplete_utf8(value) do
    if String.valid?(value),
      do: value,
      else: trim_incomplete_utf8(binary_part(value, 0, byte_size(value) - 1))
  end
end
