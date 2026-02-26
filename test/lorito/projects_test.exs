defmodule Lorito.ProjectsTest do
  use Lorito.DataCase
  import Lorito.Test.Generators

  describe "projects" do
    test "subdomain uniqueness" do
      user = generate(user())
      project1 = generate(project(actor: user, subdomain: "testsubdomain"))
      assert project1.subdomain == "testsubdomain"

      # Attempt to create a second project with the same subdomain
      assert_raise Ash.Error.Invalid, fn ->
        generate(project(actor: user, subdomain: "testsubdomain"))
      end
    end

    test "actor is assigned on project creation" do
      user = generate(user())
      project = generate(project(actor: user))
      assert project.user_id == user.id
    end
  end
end
