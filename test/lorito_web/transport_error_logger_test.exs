defmodule LoritoWeb.TransportErrorLoggerTest do
  use Lorito.DataCase, async: true

  import Lorito.Test.Generators

  test "persists a Cowboy protocol error in the matching workspace" do
    user = generate(user())
    project = generate(project(actor: user))
    workspace = generate(workspace(project: project, actor: user))
    url = "/#{project.id}/#{workspace.id}?source=transport"

    metadata = %{
      reason: {:connection_error, :protocol_error, "invalid header"},
      partial_req: %{
        peer: {{127, 0, 0, 1}, 41_000},
        method: "POST",
        path: "/#{project.id}/#{workspace.id}",
        qs: "source=transport",
        headers: %{"host" => "localhost", "x-binary" => <<255>>}
      }
    }

    assert {:ok, log} = LoritoWeb.TransportErrorLogger.persist(metadata)
    assert log.ip == "127.0.0.1"
    assert log.method == "POST"
    assert log.url == url
    assert log.workspace_id == workspace.id
    assert log.project_id == project.id
    assert ["x-binary", "base64:/w=="] in log.headers
    assert log.body == ""
    assert log.params == %{}
    assert log.error == "invalid header"
  end

  test "does not persist internal paths or authenticated session cookies" do
    base_request = %{
      peer: {{127, 0, 0, 1}, 41_000},
      method: "GET",
      path: "/_lorito/dashboard",
      qs: "",
      headers: %{}
    }

    assert :ignored =
             LoritoWeb.TransportErrorLogger.persist(%{
               reason: :bad_request,
               partial_req: base_request
             })

    assert :ignored =
             LoritoWeb.TransportErrorLogger.persist(%{
               reason: :bad_request,
               partial_req: %{
                 base_request
                 | path: "/public",
                   headers: %{"cookie" => "_lorito_key=secret"}
               }
             })

    assert Ash.read!(Lorito.Logs.HTTP) == []
  end
end
