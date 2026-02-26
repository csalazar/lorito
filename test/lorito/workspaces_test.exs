defmodule Lorito.WorkspacesTest do
  use Lorito.DataCase
  import Lorito.Test.Generators

  describe "workspaces" do
    test "path uniqueness" do
      user = generate(user())
      project = generate(project(actor: user))
      generate(workspace(project: project, actor: user, path: "custom-path"))

      assert_raise Ash.Error.Invalid, fn ->
        generate(workspace(project: project, actor: user, path: "custom-path"))
      end
    end

    test "actor is assigned on workspace creation" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      assert workspace.user_id == user.id
    end
  end
end
