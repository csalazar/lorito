defmodule Lorito.LogsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lorito.Logs` context.
  """

  @doc """
  Generate a log.
  """
  def log_fixture(attrs \\ %{}) do
    {:ok, log} =
      attrs
      |> Enum.into(%{
        ip: "some ip",
        body: "some body",
        url: "some url",
        headers: [["x-header", "value"]],
        method: "GET"
      })
      |> Lorito.Logs.create_log()

    log
  end
end
