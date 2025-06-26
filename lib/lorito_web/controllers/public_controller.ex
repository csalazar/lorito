alias LoritoWeb.ResponseHandler
alias Lorito.Workspaces
alias Lorito.Workspaces.Workspace
alias Lorito.Responses
alias Lorito.Responses.Response
alias Lorito.Logs
alias Lorito.Utils.RequestParser

defmodule RequestLogger do
  def log(conn, workspace) do
    conn
    |> Logs.gather_log_attributes()
    |> Map.put(:workspace_id, workspace.id)
    |> Map.put(:project_id, workspace.project_id)
    |> Logs.create_log()
  end

  def log(conn) do
    attributes =
      conn
      |> Logs.gather_log_attributes()

    if not RequestParser.is_internal_request(attributes) do
      attributes
      |> Logs.create_log()
    end
  end
end

defmodule LoritoWeb.ResponseHandler do
  @doc """
  Gets the response for a given route. Otherwise, tries with a wildcard route.

  Returns `{:ok, Response.t()}` or `{:not_found, nil}`.
  """
  def get_response_for_route(source_responses, route) do
    responses = Enum.filter(source_responses, fn r -> r.route == route end)

    case responses do
      [response] ->
        {:ok, response}

      [] ->
        case Enum.find(source_responses, fn r -> r.route == "*" end) do
          nil -> {:not_found, nil}
          response -> {:ok, response}
        end
    end
  end

  @doc """
  Replaces placeholders in the body with response routes.

  Returns `String.t()`.

  """
  def replace_placeholders(%Response{placeholders: []} = response) do
    response.body
  end

  def replace_placeholders(%Response{body: body, placeholders: placeholders}) do
    placeholders
    |> Enum.reduce(body, fn %Response.Placeholder{} = placeholder, modified_body ->
      response = Responses.get_response!(placeholder.value)
      String.replace(modified_body, placeholder.icon, response.route)
    end)
  end

  def prepare_response_data(%Response{} = response, %Workspace{} = workspace) do
    body = replace_placeholders(response)

    body =
      with {:ok, template} <- Solid.parse(body) do
        Solid.render!(
          template,
          %{
            "workspace_url" => LoritoWeb.Utils.build_workspace_url(workspace)
          },
          custom_filters: LoritoWeb.Utils.SolidCustomFilters
        )
        |> to_string()
      end

    if response.delay do
      :timer.sleep(response.delay * 1_000)
    end

    headers =
      response.headers
      |> Enum.map(fn %Lorito.Responses.Response.Header{} = header ->
        {header.name, header.value}
      end)
      |> List.insert_at(0, {"content-type", response.content_type})

    %{status: response.status, body: body, headers: headers}
  end

  def find_response(workspace, route) do
    route = if Enum.empty?(route), do: "/", else: Enum.join(route, "/")

    with {:ok, rebinding} <- Workspaces.Rebindings.get_rebinding(workspace, route) do
      index =
        Enum.find_index(rebinding.activations, fn a -> a == 1 end)

      response =
        Enum.at(rebinding.responses, index)
        |> Responses.get_response!()

      {:ok, response}
    else
      {:not_found, nil} ->
        base_responses =
          if workspace.template_id do
            Lorito.Templates.get_template!(workspace.template_id).responses
          else
            workspace.responses
          end

        get_response_for_route(base_responses, route)
    end
  end
end

defmodule LoritoWeb.PublicController do
  use LoritoWeb, :controller

  @doc """
  Get workspace for a custom path or a project/workspace path.
  If not found, return :catch_all to log the request as a catch-all log.

  Returns `%{workspace: Workspace.t(), route: [String.t()]}` or `:catch_all`.
  """
  def get_workspace(path) do
    # Check if the path is a custom path
    case Workspaces.get_workspace(%{path: path}) do
      %Workspace{} = workspace ->
        {:ok, workspace, []}

      nil ->
        with [project_id, workspace_id | route] <- path |> String.split("/"),
             workspace_id <- String.slice(workspace_id, 0, 6),
             workspace <-
               Workspaces.get_workspace(%{project: project_id, id: workspace_id}) do
          {:ok, workspace, route}
        else
          _ ->
            {:not_found, :catch_all}
        end
    end
  end

  def rate_limit({:not_found, :catch_all}, _conn) do
    # 5 requests in 1 minute
    key = "catch_all"
    scale = :timer.minutes(1)
    limit = 5

    case LoritoWeb.RateLimit.hit(key, scale, limit) do
      {:allow, _count} ->
        {:ok, :catch_all}

      {:deny, _limit} ->
        {:rate_limit, :catch_all}
    end
  end

  def rate_limit({:ok, workspace, route}, _conn) do
    # 20 requests in 1 minutes
    # rate limit at project level to avoid workspace enumeration
    key = "project_#{workspace.project_id}"
    scale = :timer.minutes(1)
    limit = 20

    case LoritoWeb.RateLimit.hit(key, scale, limit) do
      {:allow, _count} ->
        {:ok, :workspace, %{workspace: workspace, route: route}}

      {:deny, _limit} ->
        {:rate_limit, :workspace}
    end
  end

  def forward_request({:rate_limit, _}, conn) do
    conn |> put_status(429) |> json(nil)
  end

  def forward_request({:ok, :catch_all}, conn) do
    RequestLogger.log(conn)
    conn |> put_status(404) |> json(nil)
  end

  def forward_request({:ok, :workspace, %{workspace: workspace, route: route}}, conn) do
    {:ok, _} = RequestLogger.log(conn, workspace)

    case ResponseHandler.find_response(workspace, route) do
      {:ok, response} ->
        %{status: status, body: body, headers: headers} =
          ResponseHandler.prepare_response_data(response, workspace)

        conn
        |> resp(status, body)
        |> merge_resp_headers(headers)

      {:not_found, _} ->
        conn |> put_status(404) |> json(nil)
    end
  end

  @doc """
  Main entrypoint for handling requests.
  """
  def process_requests(conn, %{"route" => paths} = _params) do
    path = Enum.join(paths, "/")

    # _lorito application paths are handled by the Phoenix router
    # however, not registered paths will end up here
    if String.starts_with?(path, "_lorito") do
      conn |> put_status(404) |> json(nil)
    else
      get_workspace(path)
      |> rate_limit(conn)
      |> forward_request(conn)
    end
  end
end
