alias Lorito.Workspaces.Workspace
alias Lorito.Projects.Project
alias Lorito.Responses.Response

defmodule LoritoWeb.Utils do
  def format_bytes(size) when size < 1_000, do: "#{size} bytes"
  def format_bytes(size) when size < 1_000_000, do: format_byte_unit(size, 1_000, "KB")
  def format_bytes(size), do: format_byte_unit(size, 1_000_000, "MB")

  defp format_byte_unit(size, divisor, unit) do
    value = :erlang.float_to_binary(size / divisor, decimals: 2)
    "#{value} #{unit}"
  end

  def get_subdomain(request_host) do
    server_host =
      LoritoWeb.Endpoint.url()
      |> URI.parse()
      |> Map.get(:host)

    if request_host == server_host do
      nil
    else
      pattern = Regex.compile!("\\.#{Regex.escape(server_host)}$")
      String.replace(request_host, pattern, "")
    end
  end

  def add_subdomain_to_url(url, %Project{subdomain: nil}) do
    url
  end

  def add_subdomain_to_url(url, %Project{subdomain: subdomain}) do
    uri = URI.parse(url)
    uri = %{uri | host: "#{subdomain}.#{uri.host}"}
    URI.to_string(uri)
  end

  def build_workspace_url(%Workspace{} = workspace) do
    LoritoWeb.Endpoint.url()
    |> add_subdomain_to_url(workspace.project)
    |> URI.merge(workspace.computed_path)
    |> URI.to_string()
  end

  def build_response_url(%Workspace{} = workspace, %Response{} = response) do
    workspace_url = build_workspace_url(workspace)

    case response.route do
      "*" -> workspace_url
      "/" -> workspace_url
      route -> "#{build_workspace_url(workspace)}/#{route}"
    end
  end

  def format_datetime(date, current_user) do
    timezone = current_user.timezone
    local = date |> Timex.Timezone.convert("UTC") |> Timex.Timezone.convert(timezone)
    today = DateTime.utc_now() |> Timex.Timezone.convert(timezone) |> DateTime.to_date()
    local_date = DateTime.to_date(local)

    format =
      cond do
        local_date == today -> "Today at %H:%M:%S"
        local_date == Date.add(today, -1) -> "Yesterday at %H:%M:%S"
        true -> "%b %d, %Y at %H:%M:%S"
      end

    Timex.format!(local, format, :strftime)
  end

  def is_in_scope?(fqdn) do
    server_host =
      LoritoWeb.Endpoint.url()
      |> URI.parse()
      |> Map.get(:host)

    fqdn == server_host or String.ends_with?(fqdn, ".#{server_host}")
  end
end

defmodule LoritoWeb.Utils.SolidCustomFilters do
  def http_protocol(url), do: String.replace(url, ~r/^https:/, "http:")
  def no_protocol(url), do: String.replace(url, ~r/^https?:/, "")
end
