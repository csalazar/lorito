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

  test "nested arrays and non-string screenshot params render safely", %{conn: conn} do
    params = %{
      "_json" => [1, "two", %{"three" => 3}],
      "screenshot" => %{"unexpected" => true},
      "empty" => nil,
      "enabled" => false
    }

    log = generate(http_log(params: params))
    {:ok, view, _} = live(conn, "/_lorito/logs/#{log.id}")
    assert has_element?(view, "td", Jason.encode!(params["_json"]))
    assert has_element?(view, "td", Jason.encode!(params["screenshot"]))
    assert has_element?(view, "td", "null")
    assert has_element?(view, "td", "false")
  end

  test "missing logs return 404", %{conn: conn} do
    assert get(conn, "/_lorito/logs/#{Ash.UUID.generate()}/body") |> response(404) == "Not found"
  end

  defp upload_log do
    bytes = <<0, 255, 254, 65>>

    body =
      "--files\r\nContent-Disposition: form-data; name=\"note\"\r\n\r\nhello\r\n" <>
        "--files\r\nContent-Disposition: form-data; name=\"file\"; filename=\"../binary.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n" <>
        bytes <>
        "\r\n--files\r\nContent-Disposition: form-data; name=\"file\"; filename=\"empty.txt\"\r\n\r\n\r\n--files--\r\n"

    {generate(
       http_log(
         body: Base.encode64(body),
         body_encoding: "base64",
         headers: [["content-type", "multipart/form-data; boundary=\"files\""]]
       )
     ), bytes}
  end

  test "recovers repeated file fields and downloads binary and empty files", %{conn: conn} do
    {log, bytes} = upload_log()
    {:ok, view, _} = live(conn, "/_lorito/logs/#{log.id}")
    assert has_element?(view, "a[href='/_lorito/logs/#{log.id}/uploads/1']", "Download file")
    assert has_element?(view, "a[href='/_lorito/logs/#{log.id}/uploads/2']", "Download file")
    assert render(view) =~ "empty.txt"

    download = get(conn, "/_lorito/logs/#{log.id}/uploads/1")
    assert response(download, 200) == bytes
    disposition = Plug.Conn.get_resp_header(download, "content-disposition") |> hd()
    assert disposition =~ "binary.bin"
    refute disposition =~ "../"
    assert get(conn, "/_lorito/logs/#{log.id}/uploads/2") |> response(200) == ""
    assert get(conn, "/_lorito/logs/#{log.id}/uploads/99") |> response(404) == "Not found"
    assert get(conn, "/_lorito/logs/#{log.id}/uploads/invalid") |> response(404) == "Not found"

    assert get(build_conn(), "/_lorito/logs/#{log.id}/uploads/1") |> redirected_to() ==
             "/_lorito/sign-in"
  end

  test "removes Unicode formatting controls from recovered filenames", %{conn: conn} do
    deceptive_name = "invoice\u202Efdp.exe"
    zero_width_name = "résumé\u200B📄.txt"

    body =
      "--files\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{deceptive_name}\"\r\n\r\nfirst\r\n" <>
        "--files\r\nContent-Disposition: form-data; name=\"file\"; filename=\"#{zero_width_name}\"\r\n\r\nsecond\r\n--files--\r\n"

    log =
      generate(
        http_log(
          body: body,
          headers: [["content-type", "multipart/form-data; boundary=files"]]
        )
      )

    {:ok, view, _} = live(conn, "/_lorito/logs/#{log.id}")
    html = render(view)

    assert html =~ "invoicefdp.exe"
    assert html =~ "résumé📄.txt"
    refute has_element?(view, "span", deceptive_name)
    refute has_element?(view, "span", zero_width_name)

    download = get(conn, "/_lorito/logs/#{log.id}/uploads/0")
    disposition = Plug.Conn.get_resp_header(download, "content-disposition") |> hd()
    assert response(download, 200) == "first"
    assert disposition =~ "invoicefdp.exe"
    refute disposition =~ "%E2%80%AE"
  end

  test "incomplete uploads do not break the view or offer partial file downloads", %{conn: conn} do
    log =
      generate(
        http_log(
          body:
            "--files\r\nContent-Disposition: form-data; name=\"file\"; filename=\"partial.txt\"\r\n\r\nunfinished",
          headers: [["content-type", "multipart/form-data; boundary=files"]]
        )
      )

    {:ok, view, _} = live(conn, "/_lorito/logs/#{log.id}")
    refute has_element?(view, "a[href*='/uploads/']")
    assert get(conn, "/_lorito/logs/#{log.id}/uploads/0") |> response(404) == "Not found"
  end
end
