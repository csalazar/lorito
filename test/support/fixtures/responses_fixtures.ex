defmodule Lorito.ResponsesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lorito.Responses` context.
  """
  import Lorito.WorkspacesFixtures

  @doc """
  Generate a response.
  """
  def response_fixture(attrs \\ %{}, opts \\ []) do
    workspace =
      case Keyword.fetch(opts, :workspace) do
        :error -> workspace_fixture(%{})
        {:ok, value} -> value
      end

    {:ok, response} =
      attrs
      |> Enum.into(%{
        "status" => 200,
        "body" => "some body",
        "route" => "abc"
      })
      |> Lorito.Responses.create_response(workspace)

    response
  end
end
