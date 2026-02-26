defmodule Lorito.Responses do
  use Ash.Domain,
    otp_app: :lorito,
    extensions: [AshPhoenix]

  forms do
    form(:create_response_for_template, args: [:template_id])
    form(:create_response_for_workspace, args: [:workspace_id])
  end

  resources do
    resource Lorito.Responses.Response do
      define :list_responses, action: :read
      define :create_response_for_template, action: :create
      define :create_response_for_workspace, action: :create
      define :delete_response, action: :destroy
      define :update_response, action: :update
      define :get_response_by_id, action: :read, get_by: [:id]
    end
  end

  def list_http_codes do
    __MODULE__.Constants.http_codes()
  end

  def suggest_content_type(""), do: []

  def suggest_content_type(text) do
    __MODULE__.Constants.content_types()
    |> Enum.filter(fn content_type -> String.contains?(content_type, text) end)
  end
end
