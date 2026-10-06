defmodule Lorito.DnsServerTest do
  use Lorito.DataCase
  import Mock
  import Lorito.Test.Generators

  defp dns_query_binary(domain) do
    query = %DNS.Query{domain: String.to_charlist(domain), type: :a, class: :in}
    record = %DNS.Record{header: %DNS.Header{qr: false, rd: true}, qdlist: [query]}
    DNS.Record.encode(record)
  end

  defp fake_state do
    {:ok, ipv4} = "127.0.0.1" |> to_charlist() |> :inet.parse_address()
    {:ok, ipv6} = "::1" |> to_charlist() |> :inet.parse_address()

    %{
      socket: nil,
      server_data: %{
        domain: "lorito.test",
        port: 53,
        public_ip_ipv4: ipv4,
        public_ip_ipv6: ipv6,
        binding_ip: {0, 0, 0, 0}
      }
    }
  end

  defp put_settings!(data) do
    {:ok, setting} = Lorito.Settings.get_settings()
    Lorito.Settings.update_settings!(setting, %{data: data})
  end

  defp dns_settings(overrides \\ %{}) do
    Map.merge(
      %{
        "dns_enabled" => true,
        "dns_domain" => "lorito.test",
        "dns_ipv4_address" => "127.0.0.1",
        "dns_ipv6_address" => "::1",
        "scoped_mode" => false
      },
      overrides
    )
  end

  defp malformed_packets do
    valid = dns_query_binary("localhost")

    [
      <<>>,
      <<0>>,
      binary_part(valid, 0, 11),
      binary_part(valid, 0, byte_size(valid) - 1),
      <<0::16, 0::16, 1::16, 0::48, 0xC0, 12, 1::16, 1::16>>,
      <<0::16, 0::16, 1::16, 0::48, 0xC0, 255, 1::16, 1::16>>
    ]
  end

  test "malformed packets are ignored without logging" do
    state = fake_state()

    for packet <- malformed_packets() do
      assert Lorito.DnsServer.get_dns_record(packet) == nil

      assert {:noreply, ^state} =
               Lorito.DnsServer.handle_info({:udp, nil, {127, 0, 0, 1}, 1234, packet}, state)
    end

    assert Ash.read!(Lorito.Logs.DNS) == []
  end

  test "empty questions and unsupported classes are ignored" do
    state = fake_state()
    query = %DNS.Query{domain: ~c"localhost", type: :a, class: 65_000}
    record = %DNS.Record{header: %DNS.Header{}, qdlist: [query]}

    for packet <- [DNS.Record.encode(record), DNS.Record.encode(%{record | qdlist: []})] do
      assert %DNS.Record{} = Lorito.DnsServer.get_dns_record(packet)

      assert {:noreply, ^state} =
               Lorito.DnsServer.handle_info({:udp, nil, {127, 0, 0, 1}, 1234, packet}, state)
    end

    assert Ash.read!(Lorito.Logs.DNS) == []
  end

  @tag capture_log: true
  test "response encoding exceptions are contained at the packet boundary" do
    state = fake_state()
    packet = dns_query_binary("localhost")

    with_mock DNS.Record, [:passthrough], encode: fn _ -> raise ArgumentError end do
      assert {:noreply, ^state} =
               Lorito.DnsServer.handle_info({:udp, nil, {127, 0, 0, 1}, 1234, packet}, state)
    end

    assert Ash.read!(Lorito.Logs.DNS) == []
  end

  @tag capture_log: true
  test "send errors do not crash packet processing" do
    state = fake_state()

    with_mock Socket.Datagram, send: fn _, _, _ -> {:error, :ehostunreach} end do
      assert {:noreply, ^state} =
               Lorito.DnsServer.handle_info(
                 {:udp, nil, {127, 0, 0, 1}, 1234, dns_query_binary("localhost")},
                 state
               )
    end

    assert [%{query_name: "localhost"}] = Ash.read!(Lorito.Logs.DNS)
  end

  test "listener survives repeated malformed packets and answers a valid query" do
    server_data = %{fake_state().server_data | port: 0, binding_ip: {127, 0, 0, 1}}

    server =
      start_supervised!(%{
        id: :isolated_dns,
        start: {GenServer, :start_link, [Lorito.DnsServer, server_data]},
        restart: :temporary
      })

    monitor = Process.monitor(server)
    {:ok, client} = :gen_udp.open(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_udp.close(client) end)
    {:ok, port} = :inet.port(:sys.get_state(server).socket)

    for _ <- 1..5, packet <- malformed_packets() do
      :ok = :gen_udp.send(client, {127, 0, 0, 1}, port, packet)
    end

    :ok = :gen_udp.send(client, {127, 0, 0, 1}, port, dns_query_binary("localhost"))
    assert {:ok, {_, ^port, response}} = :gen_udp.recv(client, 0, 2_000)

    assert %DNS.Record{anlist: [%DNS.Resource{data: {127, 0, 0, 1}}]} =
             DNS.Record.decode(response)

    # Synchronize after the response so logging has also finished.
    assert :sys.get_state(server).socket
    assert Process.alive?(server)
    refute_received {:DOWN, ^monitor, :process, ^server, _}
    assert [%{query_name: "localhost"}] = Ash.read!(Lorito.Logs.DNS)
  end

  describe "when dns is enabled" do
    setup do
      put_settings!(dns_settings())

      :ok
    end

    test "binds the configured unprivileged DNS port" do
      original_port = Application.get_env(:lorito, :dns_port)
      {:ok, probe} = :gen_udp.open(0, [:binary, active: false])
      {:ok, port} = :inet.port(probe)
      :gen_udp.close(probe)
      Application.put_env(:lorito, :dns_port, port)

      on_exit(fn ->
        if original_port,
          do: Application.put_env(:lorito, :dns_port, original_port),
          else: Application.delete_env(:lorito, :dns_port)
      end)

      {:ok, server} = Lorito.DnsServer.start_link([])

      try do
        state = :sys.get_state(server)
        assert state.server_data.port == port
        assert {:ok, ^port} = :inet.port(state.socket)
      after
        GenServer.stop(server)
      end
    end

    test "creates a dns log for an in-scope query" do
      user = generate(user())
      project = generate(project(subdomain: "testproject", actor: user))

      fqdn = "testproject.localhost"

      with_mock Socket.Datagram, send: fn _, _, _ -> :ok end do
        Lorito.DnsServer.handle_info(
          {:udp, nil, {127, 0, 0, 1}, 1234, dns_query_binary(fqdn)},
          fake_state()
        )
      end

      dns_logs = Ash.read!(Lorito.Logs.DNS)
      assert length(dns_logs) == 1
      [log] = dns_logs
      assert log.query_name == fqdn
      assert log.record_type == "A"
      assert log.project_id == project.id
    end

    test "does not create a log for out-of-scope queries" do
      with_mock LoritoWeb.Utils, [:passthrough], is_in_scope?: fn _ -> false end do
        Lorito.DnsServer.handle_info(
          {:udp, nil, {127, 0, 0, 1}, 1234, dns_query_binary("other.domain.com")},
          fake_state()
        )
      end

      assert Ash.read!(Lorito.Logs.DNS) == []
    end

    test "does not answer or log a name that merely ends with the server host" do
      with_mock Socket.Datagram, send: fn _, _, _ -> flunk("answered an out-of-scope name") end do
        assert {:noreply, _} =
                 Lorito.DnsServer.handle_info(
                   {:udp, nil, {127, 0, 0, 1}, 1234, dns_query_binary("notlocalhost")},
                   fake_state()
                 )
      end

      assert Ash.read!(Lorito.Logs.DNS) == []
    end

    test "does not create unscoped dns logs when scoped mode is enabled" do
      put_settings!(dns_settings(%{"scoped_mode" => true}))

      with_mock LoritoWeb.Utils, [:passthrough],
        is_in_scope?: fn _ -> true end,
        get_subdomain: fn _ -> nil end do
        with_mock Socket.Datagram, send: fn _, _, _ -> :ok end do
          Lorito.DnsServer.handle_info(
            {:udp, nil, {127, 0, 0, 1}, 1234, dns_query_binary("lorito.test")},
            fake_state()
          )
        end
      end

      assert Ash.read!(Lorito.Logs.DNS) == []
    end

    test "creates scoped dns logs when scoped mode is enabled" do
      put_settings!(dns_settings(%{"scoped_mode" => true}))

      user = generate(user())
      project = generate(project(subdomain: "testproject", actor: user))

      with_mock LoritoWeb.Utils, [:passthrough],
        is_in_scope?: fn _ -> true end,
        get_subdomain: fn _ -> "testproject" end do
        with_mock Socket.Datagram, send: fn _, _, _ -> :ok end do
          Lorito.DnsServer.handle_info(
            {:udp, nil, {127, 0, 0, 1}, 1234, dns_query_binary("testproject.lorito.test")},
            fake_state()
          )
        end
      end

      [log] = Ash.read!(Lorito.Logs.DNS)
      assert log.project_id == project.id
    end
  end

  describe "start_link/1 when dns is disabled" do
    setup do
      put_settings!(%{
        "dns_enabled" => false,
        "dns_domain" => "",
        "dns_ipv4_address" => "0.0.0.0",
        "dns_ipv6_address" => "::"
      })

      :ok
    end

    test "returns :ignore" do
      assert :ignore = Lorito.DnsServer.start_link([])
    end
  end
end
