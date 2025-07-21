alias Lorito.Workspaces.Workspace
alias Lorito.Projects.Project
alias Lorito.Responses.Response

defmodule LoritoWeb.Utils do
  def get_subdomain(conn) do
    request_host = conn.host

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
    |> URI.merge(Workspace.get_path(workspace))
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

    Timex.format!(
      Timex.Timezone.convert(date, "UTC")
      |> Timex.Timezone.convert(timezone),
      "%b %d, %Y at %H:%M:%S",
      :strftime
    )
  end
end

defmodule LoritoWeb.Utils.SolidCustomFilters do
  def http_protocol(url), do: String.replace(url, ~r/^https:/, "http:")
  def no_protocol(url), do: String.replace(url, ~r/^https?:/, "")
end
