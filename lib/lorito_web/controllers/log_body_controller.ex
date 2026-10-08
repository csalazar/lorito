defmodule LoritoWeb.LogBodyController do
  use LoritoWeb, :controller

  def upload(conn, %{"id" => id, "index" => index}) do
    with {index, ""} when index >= 0 <- Integer.parse(index),
         {:ok, log} when not is_nil(log) <-
           Ash.get(Lorito.Logs.HTTP, id, actor: conn.assigns.current_user),
         {:ok, file, bytes} <- Lorito.Utils.UploadRecovery.download(log, index) do
      filename = file.filename |> String.replace("\\", "/") |> Path.basename()
      filename = String.replace(filename, ~r/[\x00-\x1f\x7f]/u, "_")
      filename = if filename in ["", ".", ".."], do: "upload", else: filename

      conn
      |> put_resp_header("cache-control", "private, no-store")
      |> send_download({:binary, bytes},
        filename: filename,
        content_type: "application/octet-stream"
      )
    else
      _ -> send_resp(conn, 404, "Not found")
    end
  end

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
