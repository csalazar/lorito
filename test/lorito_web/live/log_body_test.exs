defmodule LoritoWeb.LogBodyTest do
  use Lorito.DataCase

  import Lorito.Test.Generators
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint LoritoWeb.Endpoint

  setup do
    user = generate(user())
    {:ok, token, _} = AshAuthentication.Jwt.token_for_user(user)
    user = Ash.Resource.put_metadata(user, :token, token)

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(user)

    %{conn: conn}
  end

  test "large bodies have a bounded preview and an exact full download", %{conn: conn} do
    body = String.duplicate("x", 8_000_001) <> "END-OF-PAYLOAD"
    log = generate(http_log(body: body))
    {:ok, view, html} = live(conn, "/_lorito/logs/#{log.id}")

    assert byte_size(html) < 100_000
    assert has_element?(view, "#body-preview", String.duplicate("x", 64_000))
    refute html =~ "END-OF-PAYLOAD"
    assert has_element?(view, "dt .badge", "Preview")
    assert has_element?(view, "#body-size", "8.00 MB")
    assert has_element?(view, "#download-full-body[href='/_lorito/logs/#{log.id}/body']")

    downloaded = get(conn, "/_lorito/logs/#{log.id}/body")
    assert response(downloaded, 200) == body
    assert Plug.Conn.get_resp_header(downloaded, "content-disposition") |> hd() =~ "attachment"
  end

  test "binary downloads reproduce original bytes", %{conn: conn} do
    bytes = <<0, 255, 254, 65>>
    log = generate(http_log(body: Base.encode64(bytes), body_encoding: "base64"))
    {:ok, view, _} = live(conn, "/_lorito/logs/#{log.id}")
    assert has_element?(view, "#body-preview", Base.encode64(bytes))
    assert has_element?(view, "#body-size", "4 bytes")
    assert get(conn, "/_lorito/logs/#{log.id}/body") |> response(200) == bytes
  end

  test "preview ends on a valid UTF-8 boundary", %{conn: conn} do
    body = String.duplicate("x", 63_999) <> "é trailing"
    log = generate(http_log(body: body))
    {:ok, view, _} = live(conn, "/_lorito/logs/#{log.id}")
    assert has_element?(view, "#body-preview", String.duplicate("x", 63_999))
    refute render(view) =~ "é trailing"
  end

  test "downloads require authentication" do
    log = generate(http_log(body: "private payload"))
    conn = get(build_conn(), "/_lorito/logs/#{log.id}/body")
    assert redirected_to(conn) == "/_lorito/sign-in"
    refute conn.resp_body =~ "private payload"
  end

  test "missing logs return 404", %{conn: conn} do
    assert get(conn, "/_lorito/logs/#{Ash.UUID.generate()}/body") |> response(404) == "Not found"
  end
end
