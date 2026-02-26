defmodule Lorito.IntegrationsTest do
  use Lorito.DataCase
  import Lorito.Test.Generators

  describe "integrations" do
    test "actor is assigned on integration creation" do
      user = generate(user())
      integration = generate(integration(actor: user))

      assert integration.user_id == user.id
    end
  end
end
