defmodule Lorito.WorkspacesTest do
  use Lorito.DataCase

  alias Lorito.Workspaces
  alias Lorito.Workspaces.Workspace
  import Lorito.AccountsFixtures

  setup do
    owner = user_fixture()

    Lorito.Repo.put_user(owner)

    {:ok, owner: owner}
  end

  describe "workspaces" do
    import Lorito.WorkspacesFixtures
    import Lorito.ProjectsFixtures

    test "list_workspaces/1 returns all workspaces in project" do
      project_1 = project_fixture()
      project_2 = project_fixture()

      workspace_fixture(%{}, project: project_1)
      workspace_fixture(%{}, project: project_1)
      workspace_fixture(%{}, project: project_2)

      assert Enum.count(Workspaces.list_workspaces(%{project: project_1})) == 2
    end

    test "get_workspace!/1 returns the workspace with given id" do
      workspace = workspace_fixture()
      w = Workspaces.get_workspace!(workspace.id)
      assert w.id == workspace.id
    end

    test "get_workspace/1 with project and id returns the right workspace" do
      workspace = workspace_fixture()
      w = Workspaces.get_workspace(%{project: workspace.project_id, id: workspace.id})
      assert w.id == workspace.id
    end

    test "get_workspace/1 with empty path returns nil" do
      w = Workspaces.get_workspace(%{path: ""})
      assert w == nil
    end

    test "get_workspace/1 with path returns the right workspace" do
      workspace = workspace_fixture(%{"path" => "custom_path"})
      w = Workspaces.get_workspace(%{path: "custom_path"})
      assert w.id == workspace.id
    end

    test "create_workspace/1 with valid data creates a workspace" do
      project = project_fixture()

      {:ok, %Workspace{} = workspace} =
        Workspaces.create_workspace(%{"name" => "ws1", "project" => project})

      assert workspace.project_id == project.id
    end

    test "create_workspace/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Workspaces.create_workspace(%{notifiable: "abc"})
    end

    test "update_workspace/2 with valid data updates the workspace" do
      workspace = workspace_fixture()
      update_attrs = %{name: "new name"}

      assert {:ok, %Workspace{} = workspace} =
               Workspaces.update_workspace(workspace, update_attrs)

      assert workspace.name == "new name"
    end

    test "delete_workspace/1 deletes the workspace" do
      workspace = workspace_fixture()
      assert {:ok, %Workspace{}} = Workspaces.delete_workspace(workspace)
      assert_raise Ecto.NoResultsError, fn -> Workspaces.get_workspace!(workspace.id) end
    end

    test "change_workspace/1 returns a workspace changeset" do
      workspace = workspace_fixture()
      assert %Ecto.Changeset{} = Workspaces.change_workspace(workspace)
    end
  end
end
