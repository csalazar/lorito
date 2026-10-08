defmodule LoritoWeb.Plugs.ResilientParsers do
  @moduledoc false
  @behaviour Plug

  alias LoritoWeb.Plugs.CaptureBody

  @parser_errors [
    Plug.BadRequestError,
    Plug.Conn.InvalidQueryError,
    Plug.Parsers.BadEncodingError,
    Plug.Parsers.ParseError,
    Plug.Parsers.RequestTooLargeError
  ]

  @impl true
  def init(opts), do: Plug.Parsers.init(opts)

  @impl true
  def call(conn, opts) do
    Plug.Parsers.call(conn, opts)
  rescue
    _error in @parser_errors ->
      conn
      |> CaptureBody.recover()
      |> discard_malformed_params()
  end

  defp discard_malformed_params(conn) do
    %{conn | body_params: %{}, query_params: %{}, params: %{}}
  end
end
