defmodule Lorito.TemplatesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lorito.Templates` context.
  """

  @doc """
  Generate a template.
  """
  def template_fixture(attrs \\ %{}) do
    {:ok, template} =
      attrs
      |> Enum.into(%{
        name: "some name"
      })
      |> Lorito.Templates.create_template()

    template
  end
end
