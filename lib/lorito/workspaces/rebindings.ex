defmodule Lorito.Workspaces.Rebindings do
  alias Lorito.Workspaces.Workspace
  alias Lorito.Responses.Response
  alias Lorito.Workspaces.WorkspaceRepo

  @available_icons ["🐙", "🐼", "🐤", "🐸", "🐳", "🦆"]

  defp add_response_to_rebinding(rebindings, %Response{} = response) do
    Enum.map(rebindings, fn r ->
      if r.route == response.route do
        %{r | responses: r.responses ++ [response.id], activations: r.activations ++ [0]}
      else
        r
      end
    end)
  end

  defp delete_response_from_rebinding(rebindings, %Response{} = response) do
    Enum.map(rebindings, fn r ->
      if r.route == response.route do
        index = Enum.find_index(r.responses, fn r -> r == response.id end)

        %{
          r
          | responses: List.delete_at(r.responses, index),
            activations: List.delete_at(r.activations, index)
        }
      else
        r
      end
    end)
  end

  defp get_icon(rebindings) do
    Enum.find(@available_icons, fn icon ->
      Enum.all?(rebindings, fn r -> r.icon != icon end)
    end)
  end

  defp add_new_rebinding(rebindings, responses, route) do
    response_ids =
      Enum.filter(responses, fn r -> r.route == route end)
      |> Enum.map(fn r -> r.id end)

    new_rebinding = %{
      route: route,
      responses: response_ids,
      activations: [1, 0],
      strategy: "manual",
      icon: get_icon(rebindings)
    }

    [new_rebinding | rebindings]
  end

  defp delete_rebinding(rebindings, route),
    do: Enum.reject(rebindings, fn r -> r.route == route end)

  @doc """
  Add a response to an existing rebinding or create a new one.
  """
  def promote_response_to_rebinding(
        %Workspace{responses: responses} = workspace,
        %Response{route: route} = response
      ) do
    rebindings = Enum.map(workspace.rebindings, fn r -> Map.from_struct(r) end)
    rebound_routes = Enum.map(rebindings, fn r -> r.route end)

    updated_rebindings =
      if route in rebound_routes do
        add_response_to_rebinding(rebindings, response)
      else
        add_new_rebinding(rebindings, responses, route)
      end

    WorkspaceRepo.update_workspace(workspace, %{rebindings: updated_rebindings})
  end

  @doc """
  Delete the response from the rebinding or delete the rebinding.

  `workspace` must be fully updated
  """
  def demote_response_from_rebindings(
        %Workspace{} = workspace,
        %Response{route: route} = response
      ) do
    # Get the workspace with the latest data
    workspace = WorkspaceRepo.get_workspace!(workspace.id)
    rebindings = Enum.map(workspace.rebindings, fn r -> Map.from_struct(r) end)

    must_delete_rebinding =
      Enum.filter(workspace.responses, fn r -> r.route == route end)
      |> Enum.count() == 1

    updated_rebindings =
      if must_delete_rebinding do
        delete_rebinding(rebindings, route)
      else
        delete_response_from_rebinding(rebindings, response)
      end

    WorkspaceRepo.update_workspace(workspace, %{rebindings: updated_rebindings})
  end

  def activate_response(%Workspace{} = workspace, %Response{} = response) do
    rebindings = Enum.map(workspace.rebindings, fn r -> Map.from_struct(r) end)

    updated_rebindings =
      Enum.map(rebindings, fn r ->
        if r.route == response.route do
          response_index = Enum.find_index(r.responses, fn r -> r == response.id end)

          updated_activations =
            List.duplicate(0, length(r.activations)) |> List.replace_at(response_index, 1)

          %{r | activations: updated_activations}
        else
          r
        end
      end)

    WorkspaceRepo.update_workspace(workspace, %{rebindings: updated_rebindings})
  end

  def get_rebinding(%Workspace{} = workspace, route) do
    case Enum.find(workspace.rebindings, fn r -> r.route == route end) do
      nil -> {:not_found, nil}
      rebinding -> {:ok, rebinding}
    end
  end

  def is_response_active?(rebinding, response) do
    response_index = Enum.find_index(rebinding.responses, &(&1 == response.id))
    rebinding.activations |> Enum.at(response_index) |> Kernel.==(1)
  end
end
