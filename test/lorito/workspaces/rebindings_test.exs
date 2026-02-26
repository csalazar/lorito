defmodule Lorito.WorkspacesRebindingsTest do
  use Lorito.DataCase
  import Lorito.Test.Generators

  alias Lorito.Workspaces
  alias Lorito.Responses

  describe "promote_response_to_rebinding/2" do
    test "add new rebinding" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))

      generate(response(workspace: workspace, actor: user, route: "x"))
      response = generate(response(workspace: workspace, actor: user, route: "x"))

      workspace = Workspaces.get_workspace!(%{id: workspace.id, project_id: project.id})
      assert Enum.count(workspace.rebindings) == 0

      {:ok, _} = Workspaces.promote_response_to_rebinding(workspace, response)

      workspace = Workspaces.get_workspace!(%{id: workspace.id, project_id: project.id})
      assert Enum.count(workspace.rebindings) == 1
    end

    test "add response to existing rebinding" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      response1 = generate(response(workspace: workspace, actor: user, route: "x"))
      response2 = generate(response(workspace: workspace, actor: user, route: "x"))

      {:ok, _} =
        Workspaces.update_rebindings(workspace, [
          %{
            "route" => "x",
            "responses" => [response1.id, response2.id],
            "activations" => [1, 0],
            "strategy" => "manual",
            "icon" => "🐙"
          }
        ])

      response3 = generate(response(workspace: workspace, actor: user, route: "x"))

      # load workspace with rebinding and responses
      workspace = Workspaces.get_workspace!(%{id: workspace.id, project_id: project.id})

      {:ok, _} = Workspaces.promote_response_to_rebinding(workspace, response3)

      workspace = Workspaces.get_workspace!(%{id: workspace.id, project_id: project.id})

      assert workspace.rebindings |> List.first() |> Map.get(:responses) == [
               response1.id,
               response2.id,
               response3.id
             ]
    end
  end

  describe "demote_response_from_rebindings/2" do
    test "delete rebinding" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      response1 = generate(response(workspace: workspace, actor: user, route: "x"))
      response2 = generate(response(workspace: workspace, actor: user, route: "x"))

      {:ok, _} =
        Workspaces.update_rebindings(workspace, [
          %{
            "route" => "x",
            "responses" => [response1.id, response2.id],
            "activations" => [1, 0],
            "strategy" => "manual",
            "icon" => "🐙"
          }
        ])

      :ok = Responses.delete_response(response2)
      {:ok, _} = Workspaces.demote_response_from_rebindings(workspace, response2)

      workspace = Workspaces.get_workspace!(%{id: workspace.id, project_id: project.id})
      assert Enum.count(workspace.rebindings) == 0
    end

    test "delete response from rebinding" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      response1 = generate(response(workspace: workspace, actor: user, route: "x"))
      response2 = generate(response(workspace: workspace, actor: user, route: "x"))
      response3 = generate(response(workspace: workspace, actor: user, route: "x"))

      {:ok, _} =
        Workspaces.update_rebindings(workspace, [
          %{
            "route" => "x",
            "responses" => [response1.id, response2.id, response3.id],
            "activations" => [1, 0, 0],
            "strategy" => "manual",
            "icon" => "🐙"
          }
        ])

      :ok = Responses.delete_response(response2)
      {:ok, _} = Workspaces.demote_response_from_rebindings(workspace, response2)

      workspace = Workspaces.get_workspace!(%{id: workspace.id, project_id: project.id})
      assert Enum.count(workspace.rebindings) == 1

      assert workspace.rebindings |> List.first() |> Map.get(:responses) == [
               response1.id,
               response3.id
             ]
    end
  end
end
