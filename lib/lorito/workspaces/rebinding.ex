defmodule Lorito.Workspaces.Workspace.Rebinding do
  use Ash.Resource,
    data_layer: :embedded

  actions do
    defaults [
      :read,
      :destroy,
      :update,
      create: [:route, :responses, :activations, :strategy, :icon]
    ]
  end

  attributes do
    uuid_primary_key :id
    attribute :route, :string, allow_nil?: false
    attribute :responses, {:array, :uuid}, allow_nil?: false
    attribute :activations, {:array, :integer}, allow_nil?: false
    attribute :strategy, :string, allow_nil?: false
    attribute :icon, :string, allow_nil?: false
  end
end
