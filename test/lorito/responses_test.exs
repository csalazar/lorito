defmodule Lorito.ResponsesTest do
  use Lorito.DataCase
  import Lorito.Test.Generators

  describe "responses" do
    test "actor is assigned on response creation" do
      user = generate(user())
      project = generate(project(actor: user))

      workspace = generate(workspace(project: project, actor: user))
      response = generate(response(workspace: workspace, actor: user))

      assert response.user_id == user.id
    end
  end
end
