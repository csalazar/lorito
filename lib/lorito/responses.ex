defmodule Lorito.Responses do
  alias Lorito.Responses.ResponseRepo
  alias Lorito.Responses.Constants
  alias Lorito.Workspaces.Workspace
  alias Lorito.Templates.Template

  defdelegate list_responses(filters \\ %{}), to: ResponseRepo
  defdelegate get_response!(id), to: ResponseRepo
  defdelegate update_response(response, attrs \\ %{}), to: ResponseRepo
  defdelegate delete_response(response), to: ResponseRepo
  defdelegate change_response(response, attrs \\ %{}), to: ResponseRepo

  def create_response(attrs, %Workspace{} = workspace) do
    attrs
    |> Map.put("workspace_id", workspace.id)
    |> Map.put("template_id", nil)
    |> ResponseRepo.create_response()
  end

  def create_response(attrs, %Template{} = template) do
    attrs
    |> Map.put("workspace_id", nil)
    |> Map.put("template_id", template.id)
    |> ResponseRepo.create_response()
  end

  def suggest_content_type(""), do: []

  def suggest_content_type(text) do
    Constants.content_types()
    |> Enum.filter(fn content_type -> String.contains?(content_type, text) end)
  end

  def list_http_codes do
    Constants.http_codes()
  end
end
