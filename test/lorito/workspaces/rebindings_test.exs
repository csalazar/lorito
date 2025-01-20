defmodule Lorito.WorkspacesRebindingsTest do
  use Lorito.DataCase

  alias Lorito.Workspaces
  alias Lorito.Responses
  import Lorito.WorkspacesFixtures
  import Lorito.ResponsesFixtures
  import Lorito.AccountsFixtures

  setup do
    owner = user_fixture()

    Lorito.Repo.put_user(owner)

    {:ok, owner: owner}
  end

  describe "promote_response_to_rebinding/2" do
    test "add new rebinding" do
      workspace = workspace_fixture()
      _response_1 = response_fixture(%{"route" => "x"}, workspace: workspace)
      response_2 = response_fixture(%{"route" => "x"}, workspace: workspace)

      workspace = Workspaces.get_workspace!(workspace.id)
      assert Enum.count(workspace.rebindings) == 0

      {:ok, _} = Workspaces.promote_response_to_rebinding(workspace, response_2)

      workspace = Workspaces.get_workspace!(workspace.id)
      assert Enum.count(workspace.rebindings) == 1
    end

    test "add response to existing rebinding" do
      workspace = workspace_fixture()
      response_1 = response_fixture(%{"route" => "x"}, workspace: workspace)
      response_2 = response_fixture(%{"route" => "x"}, workspace: workspace)

      {:ok, _} =
        Workspaces.update_workspace(workspace, %{
          "rebindings" => [
            %{
              "route" => "x",
              "responses" => [response_1.id, response_2.id],
              "activations" => [1, 0],
              "strategy" => "manual",
              "icon" => nil
            }
          ]
        })

      # create the new response
      response_3 = response_fixture(%{"route" => "x"}, workspace: workspace)

      # load workspace with rebinding and responses
      workspace = Workspaces.get_workspace!(workspace.id)
      {:ok, _} = Workspaces.promote_response_to_rebinding(workspace, response_3)

      workspace = Workspaces.get_workspace!(workspace.id)

      assert workspace.rebindings |> List.first() |> Map.get(:responses) == [
               response_1.id,
               response_2.id,
               response_3.id
             ]
    end
  end

  describe "demote_response_from_rebindings/2" do
    test "delete rebinding" do
      workspace = workspace_fixture()
      response_1 = response_fixture(%{"route" => "x"}, workspace: workspace)
      response_2 = response_fixture(%{"route" => "x"}, workspace: workspace)

      {:ok, _} =
        Workspaces.update_workspace(workspace, %{
          "rebindings" => [
            %{
              "route" => "x",
              "responses" => [response_1.id, response_2.id],
              "activations" => [1, 0],
              "strategy" => "manual",
              "icon" => nil
            }
          ]
        })

      {:ok, _} = Responses.delete_response(response_2)
      {:ok, _} = Workspaces.demote_response_from_rebindings(workspace, response_2)

      workspace = Workspaces.get_workspace!(workspace.id)
      assert Enum.count(workspace.rebindings) == 0
    end

    test "delete response from rebinding" do
      workspace = workspace_fixture()
      response_1 = response_fixture(%{"route" => "x"}, workspace: workspace)
      response_2 = response_fixture(%{"route" => "x"}, workspace: workspace)
      response_3 = response_fixture(%{"route" => "x"}, workspace: workspace)

      {:ok, _} =
        Workspaces.update_workspace(workspace, %{
          "rebindings" => [
            %{
              "route" => "x",
              "responses" => [response_1.id, response_2.id, response_3.id],
              "activations" => [1, 0, 0],
              "strategy" => "manual",
              "icon" => nil
            }
          ]
        })

      {:ok, _} = Responses.delete_response(response_2)
      {:ok, _} = Workspaces.demote_response_from_rebindings(workspace, response_2)

      workspace = Workspaces.get_workspace!(workspace.id)
      assert Enum.count(workspace.rebindings) == 1

      assert workspace.rebindings |> List.first() |> Map.get(:responses) == [
               response_1.id,
               response_3.id
             ]
    end
  end
end
