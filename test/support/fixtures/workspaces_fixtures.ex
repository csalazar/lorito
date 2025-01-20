defmodule Lorito.WorkspacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lorito.Workspaces` context.
  """
  import Lorito.ProjectsFixtures

  @doc """
  Generate a workspace.
  """
  def workspace_fixture(attrs \\ %{}, opts \\ []) do
    project =
      case Keyword.fetch(opts, :project) do
        :error -> project_fixture(%{})
        {:ok, value} -> value
      end

    {:ok, workspace} =
      attrs
      |> Enum.into(%{"project" => project})
      |> Lorito.Workspaces.create_workspace()

    workspace
  end
end
