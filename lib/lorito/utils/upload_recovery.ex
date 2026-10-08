defmodule Lorito.Utils.UploadRecovery do
  @moduledoc false

  @unicode_format_characters ~r/\p{Cf}/u

  def list(log) do
    with {:ok, _body, files} <- recover(log), do: {:ok, files}
  end

  def download(log, index) do
    with {:ok, body, files} <- recover(log),
         file when not is_nil(file) <- Enum.find(files, &(&1.index == index)) do
      {:ok, file, binary_part(body, file.offset, file.size)}
    else
      _ -> {:error, :not_found}
    end
  end

  defp recover(log) do
    with [_, content_type] <- Enum.find(log.headers, fn [name, _] -> name == "content-type" end),
         {:ok, "multipart", "form-data", params} <- Plug.Conn.Utils.media_type(content_type),
         boundary when is_binary(boundary) and boundary != "" <- params["boundary"],
         {:ok, body} <- decode(log),
         {:ok, files} <- parts(body, boundary, byte_size(body), 0, []) do
      {:ok, body, files}
    else
      _ -> {:error, :invalid_multipart}
    end
  rescue
    _ -> {:error, :invalid_multipart}
  end

  defp decode(%{body_encoding: "base64", body: body}), do: Base.decode64(body)
  defp decode(%{body: body}) when is_binary(body), do: {:ok, body}

  defp parts(stream, boundary, total, index, files) do
    case :cow_multipart.parse_headers(stream, boundary) do
      {:done, _epilogue} ->
        {:ok, Enum.reverse(files)}

      {:ok, headers, rest} ->
        case :cow_multipart.parse_body(rest, boundary) do
          {:done, bytes, tail} ->
            files =
              case metadata(headers) do
                {:ok, field, filename, content_type} ->
                  [
                    %{
                      index: index,
                      field: field,
                      filename: filename,
                      content_type: content_type,
                      offset: total - byte_size(rest),
                      size: byte_size(bytes)
                    }
                    | files
                  ]

                :field ->
                  files
              end

            parts(tail, boundary, total, index + 1, files)

          _ ->
            {:error, :incomplete_multipart}
        end

      _ ->
        {:error, :incomplete_multipart}
    end
  end

  defp metadata(headers) do
    with {_, disposition} <- List.keyfind(headers, "content-disposition", 0),
         [_, attributes] <- :binary.split(disposition, ";"),
         params <- Plug.Conn.Utils.params(attributes),
         field when is_binary(field) <- params["name"],
         filename when is_binary(filename) and filename != "" <- filename(params) do
      type =
        case List.keyfind(headers, "content-type", 0) do
          {_, value} -> value
          nil -> "application/octet-stream"
        end

      {:ok, display_text(field), safe_filename(filename), display_text(type)}
    else
      _ -> :field
    end
  end

  defp filename(%{"filename" => filename}), do: filename
  defp filename(%{"filename*" => "utf-8''" <> filename}), do: URI.decode(filename)
  defp filename(_params), do: nil

  defp display_text(value) do
    if String.valid?(value), do: :binary.copy(value), else: "base64:" <> Base.encode64(value)
  end

  defp safe_filename(value) do
    case value |> display_text() |> String.replace(@unicode_format_characters, "") do
      "" -> "upload"
      filename -> filename
    end
  end
end
