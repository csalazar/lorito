defmodule Lorito.Utils.RequestParser do
  def get_ip(conn) do
    conn.remote_ip |> :inet.ntoa() |> to_string()
  end

  def get_url(conn) do
    case conn.query_string do
      "" ->
        conn.request_path

      qs ->
        "#{conn.request_path}?#{qs}"
    end
  end

  @doc false
  defp remove_fly_headers(headers) do
    headers
    |> Enum.reject(fn {header, _value} ->
      String.starts_with?(header, ["fly-", "x-forwarded-", "via", "x-request-start"])
    end)
  end

  def get_headers(conn) do
    conn.req_headers
    |> remove_fly_headers()
    # Empty headers generate insert exception despite it's a 2-element array
    |> Enum.reject(fn {_header, value} -> value == "" end)
    |> Enum.map(fn {header, value} -> [header, value] end)
  end

  def get_params(%{params: params}) do
    params
    |> Enum.reject(fn {k, _v} -> k in ["project_id", "route", "revision"] end)
    |> Enum.into(%{})
  end

  @doc """
  Return true if the request was made by the logged in user.
  It's to avoid leaking the session cookie to the logs.
  """
  def is_internal_request(%{headers: headers}) do
    headers
    |> Enum.any?(fn [header, value] ->
      header == "cookie" && String.contains?(value, "_lorito_key=")
    end)
  end
end
