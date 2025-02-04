defmodule Lorito.Accounts.UserTest do
  use Lorito.DataCase
  alias Lorito.Accounts.User
  import Lorito.AccountsFixtures

  describe "settings_changeset/2" do
    test "validates invalid timezone" do
      user = user_fixture()
      changeset = User.settings_changeset(user, %{timezone: "Planet/Mars"})
      assert !changeset.valid?
    end

    test "validates valid timezone" do
      user = user_fixture()
      changeset = User.settings_changeset(user, %{timezone: "America/Santiago"})
      assert changeset.valid?
    end
  end
end
