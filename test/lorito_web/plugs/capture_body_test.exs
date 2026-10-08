defmodule LoritoWeb.Plugs.CaptureBodyTest do
  use Lorito.DataCase, async: true
  import Lorito.Test.Generators

  defmodule ReadErrorAdapter do
    def read_req_body(_state, _opts), do: {:error, :timeout}
    def get_peer_data(state), do: Plug.Adapters.Test.Conn.get_peer_data(state)

    def send_resp(state, status, headers, body),
      do: Plug.Adapters.Test.Conn.send_resp(state, status, headers, body)
  end

  defmodule RequireConsumedAdapter do
    def read_req_body(state, opts) do
      15_000 = Keyword.fetch!(opts, :read_timeout)
      Plug.Adapters.Test.Conn.read_req_body(state, opts)
    end

    def get_peer_data(state), do: Plug.Adapters.Test.Conn.get_peer_data(state)

    def send_resp(%{req_body: ""} = state, status, headers, body),
      do: Plug.Adapters.Test.Conn.send_resp(state, status, headers, body)

    def send_resp(_state, _status, _headers, _body),
      do: raise("response used a stale adapter state")
  end

  defmodule ChunkedAdapter do
    def read_req_body(%{chunk_read?: true} = state, _opts) do
      {:ok, state.req_body, %{state | req_body: ""}}
    end

    def read_req_body(%{req_body: body} = state, _opts) do
      split_at = max(div(byte_size(body), 2), 1)
      {first, rest} = :erlang.split_binary(body, split_at)
      {:more, first, state |> Map.put(:chunk_read?, true) |> Map.put(:req_body, rest)}
    end

    def get_peer_data(state), do: Plug.Adapters.Test.Conn.get_peer_data(state)

    def send_resp(state, status, headers, body),
      do: Plug.Adapters.Test.Conn.send_resp(state, status, headers, body)
  end

  defp conn_with_adapter(adapter, body, path) do
    conn =
      Plug.Test.conn(:post, "http://localhost" <> path, body)
      |> Plug.Conn.put_req_header("content-type", "text/plain")

    {_, state} = conn.adapter
    %{conn | adapter: {adapter, state}}
  end

  defp workspace_path do
    user = generate(user())
    project = generate(project(actor: user))
    workspace = generate(workspace(project: project, actor: user))
    "/#{project.id}/#{workspace.id}"
  end

  test "a body read error returns an intentional response instead of a MatchError" do
    conn =
      conn_with_adapter(ReadErrorAdapter, "body", workspace_path()) |> LoritoWeb.Endpoint.call([])

    assert conn.status == 408
  end

  test "bounded read timeout and updated connection reach response sending" do
    conn =
      conn_with_adapter(RequireConsumedAdapter, "body", workspace_path())
      |> LoritoWeb.Endpoint.call([])

    assert conn.status == 404
    assert {RequireConsumedAdapter, _state} = conn.adapter
  end

  test "a body delivered in multiple chunks is served and logged in full" do
    body = "first chunk and second chunk"

    conn =
      conn_with_adapter(ChunkedAdapter, body, workspace_path())
      |> LoritoWeb.Endpoint.call([])

    assert conn.status == 404
    assert [%{body: ^body, body_encoding: "utf-8"}] = Ash.read!(Lorito.Logs.HTTP)
  end
end
