defmodule Lorito.IntegrationsTest do
  use Lorito.DataCase

  alias Lorito.Integrations
  import Lorito.AccountsFixtures

  setup do
    owner = user_fixture()

    Lorito.Repo.put_user(owner)

    {:ok, owner: owner}
  end

  describe "integrations" do
    alias Lorito.Integrations.Integration

    import Lorito.IntegrationsFixtures

    @invalid_attrs %{type: nil, webhook_url: nil}

    test "list_integrations/0 returns all integrations" do
      integration = integration_fixture()
      assert Integrations.list_integrations() == [integration]
    end

    test "get_integration!/1 returns the integration with given id" do
      integration = integration_fixture()
      assert Integrations.get_integration!(integration.id) == integration
    end

    test "create_integration/1 with valid data creates a integration" do
      valid_attrs = %{type: :discord, webhook_url: "https://discord.com/api/webhooks/1"}

      assert {:ok, %Integration{} = integration} = Integrations.create_integration(valid_attrs)
      assert integration.type == :discord
      assert integration.webhook_url == "https://discord.com/api/webhooks/1"
    end

    test "create_integration/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Integrations.create_integration(@invalid_attrs)
    end

    test "update_integration/2 with valid data updates the integration" do
      integration = integration_fixture()
      update_attrs = %{type: :discord, webhook_url: "https://discord.com/api/webhooks/2"}

      assert {:ok, %Integration{} = integration} =
               Integrations.update_integration(integration, update_attrs)

      assert integration.type == :discord
      assert integration.webhook_url == "https://discord.com/api/webhooks/2"
    end

    test "update_integration/2 with invalid data returns error changeset" do
      integration = integration_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Integrations.update_integration(integration, @invalid_attrs)

      assert integration == Integrations.get_integration!(integration.id)
    end

    test "delete_integration/1 deletes the integration" do
      integration = integration_fixture()
      assert {:ok, %Integration{}} = Integrations.delete_integration(integration)
      assert_raise Ecto.NoResultsError, fn -> Integrations.get_integration!(integration.id) end
    end

    test "change_integration/1 returns a integration changeset" do
      integration = integration_fixture()
      assert %Ecto.Changeset{} = Integrations.change_integration(integration)
    end
  end
end
