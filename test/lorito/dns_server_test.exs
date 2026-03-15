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

  describe "when dns is enabled" do
    setup do
      put_settings!(%{
        "dns_enabled" => true,
        "dns_domain" => "lorito.test",
        "dns_ipv4_address" => "127.0.0.1",
        "dns_ipv6_address" => "::1"
      })

      :ok
    end

    test "creates a dns log for an in-scope query" do
      user = generate(user())
      project = generate(project(subdomain: "testproject", actor: user))

      fqdn = "testproject.lorito.test"

      with_mock LoritoWeb.Utils, [:passthrough],
        is_in_scope?: fn _ -> true end,
        get_subdomain: fn _ -> "testproject" end do
        with_mock Socket.Datagram, send!: fn _, _, _ -> :ok end do
          Lorito.DnsServer.handle_info(
            {:udp, nil, {127, 0, 0, 1}, 1234, dns_query_binary(fqdn)},
            fake_state()
          )
        end
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
