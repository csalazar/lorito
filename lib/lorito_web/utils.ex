alias Lorito.Workspaces.Workspace
alias Lorito.Responses.Response

defmodule LoritoWeb.Utils do
  def build_workspace_url(%Workspace{} = workspace) do
    LoritoWeb.Endpoint.url()
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
end
