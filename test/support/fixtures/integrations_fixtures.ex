defmodule Lorito.IntegrationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lorito.Integrations` context.
  """

  @doc """
  Generate a integration.
  """
  def integration_fixture(attrs \\ %{}) do
    {:ok, integration} =
      attrs
      |> Enum.into(%{
        type: :discord,
        webhook_url: "https://discord.com/api/webhooks/1"
      })
      |> Lorito.Integrations.create_integration()

    integration
  end
end
