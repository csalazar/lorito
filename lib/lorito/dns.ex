require Logger

defmodule Lorito.DnsServer do
  use GenServer

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_args) do
    case load_server_data() do
      {:disabled} ->
        Logger.info("DNS server disabled via settings, skipping start")
        :ignore

      {:ok, server_data} ->
        GenServer.start_link(__MODULE__, server_data, name: __MODULE__)
    end
  end

  def enable do
    Supervisor.restart_child(Lorito.Supervisor, __MODULE__)
  end

  def disable do
    Supervisor.terminate_child(Lorito.Supervisor, __MODULE__)
  end

  defp load_server_data do
    data =
      case Lorito.Settings.get_settings() do
        {:ok, %{data: d}} -> d
        _ -> %{}
      end

    get_val = fn key, default ->
      case Map.get(data, key) do
        v when not is_nil(v) and v != "" -> v
        _ -> default
      end
    end

    if not get_val.("dns_enabled", false) do
      {:disabled}
    else
      domain = get_val.("dns_domain", "localhost")
      ipv4_str = get_val.("dns_ipv4_address", "127.0.0.1")
      ipv6_str = get_val.("dns_ipv6_address", "::1")

      {:ok, ipv4} = ipv4_str |> to_charlist() |> :inet.parse_address()
      {:ok, ipv6} = ipv6_str |> to_charlist() |> :inet.parse_address()

      binding_ip =
        if System.get_env("FLY_APP_NAME") do
          {:ok, fly_ip} = :inet.getaddr(~c"fly-global-services", :inet)
          fly_ip
        else
          {0, 0, 0, 0}
        end

      {:ok,
       %{
         domain: domain,
         port: 53,
         public_ip_ipv4: ipv4,
         public_ip_ipv6: ipv6,
         binding_ip: binding_ip
       }}
    end
  end

  @impl true
  def init(%{port: port, binding_ip: binding_ip} = server_data) do
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true, ip: binding_ip])

    Logger.debug(
      "DNS server started on port #{port} with binding IP #{:inet.ntoa(binding_ip) |> to_string()}"
    )

    {:ok,
     %{
       socket: socket,
       server_data: server_data
     }}
  end

  def response_by_type(:a, %{public_ip_ipv4: ip}), do: ip
  def response_by_type(:aaaa, %{public_ip_ipv6: ip}), do: ip
  def response_by_type(:cname, %{domain: domain}), do: domain
  def response_by_type(:txt, _), do: [""]
  def response_by_type(:ns, _), do: []
  def response_by_type(_, _), do: :not_supported

  def build_response(:not_supported, _, _), do: {:error, :not_supported}

  def build_response(result, record, query) do
    resource = %DNS.Resource{
      domain: query.domain,
      class: query.class,
      type: query.type,
      ttl: 0,
      data: result
    }

    response = %{record | anlist: [resource], header: %{record.header | qr: true}}
    {:ok, response}
  end

  defp send_dns_response(record, query, ip, wtv, %{socket: socket, server_data: server_data}) do
    result =
      query.type
      |> response_by_type(server_data)
      |> build_response(record, query)

    case result do
      {:error, :not_supported} ->
        Logger.debug("Unsupported DNS query type: #{query.type}")

      {:ok, response} ->
        Socket.Datagram.send!(socket, DNS.Record.encode(response), {ip, wtv})
        Logger.debug("DNS response sent.")
    end
  end

  def get_dns_record(data) do
    try do
      DNS.Record.decode(data)
    catch
      _ -> nil
    end
  end

  @impl true
  def handle_info({:udp, _client, ip, wtv, data}, state) do
    with %DNS.Record{} = record <- get_dns_record(data),
         %DNS.Query{} = query <- List.first(record.qdlist) do
      fqdn = query.domain |> to_string()

      if LoritoWeb.Utils.is_in_scope?(fqdn) do
        Logger.debug("Answering DNS query ..")
        send_dns_response(record, query, ip, wtv, state)

        Logger.debug("Logging DNS query ..")

        project_id =
          with subdomain when not is_nil(subdomain) <-
                 LoritoWeb.Utils.get_subdomain(fqdn),
               {:ok, project} <- Lorito.Projects.get_project_by_subdomain(subdomain) do
            project.id
          else
            _ -> nil
          end

        {:ok, _} =
          Lorito.Logs.create_dns_log(%{
            query_name: fqdn,
            record_type: query.type |> to_string() |> String.upcase(),
            ip: ip |> :inet_parse.ntoa() |> to_string(),
            workspace_id: nil,
            project_id: project_id
          })
      end
    end

    {:noreply, state}
  end
end
