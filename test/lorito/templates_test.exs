defmodule Lorito.TemplatesTest do
  use Lorito.DataCase
  import Lorito.Test.Generators

  describe "templates" do
    test "actor is assigned on template creation" do
      user = generate(user())
      template = generate(template(actor: user))

      assert template.user_id == user.id
    end
  end
end
