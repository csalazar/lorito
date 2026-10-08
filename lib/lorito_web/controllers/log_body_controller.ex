defmodule LoritoWeb.LogBodyController do
  use LoritoWeb, :controller

  def show(conn, %{"id" => id}) do
    case Ash.get(Lorito.Logs.HTTP, id, actor: conn.assigns.current_user) do
      {:ok, log} when not is_nil(log) ->
        body = if log.body_encoding == "base64", do: Base.decode64!(log.body), else: log.body

        conn
        |> put_resp_header("cache-control", "private, no-store")
        |> send_download({:binary, body || ""},
          filename: "lorito-request-#{log.id}.body",
          content_type: "application/octet-stream"
        )

      _ ->
        send_resp(conn, 404, "Not found")
    end
  end
end
