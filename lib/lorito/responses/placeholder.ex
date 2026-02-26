defmodule Lorito.Responses.Response.Placeholder do
  use Ash.Resource,
    data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: [:icon, :value], update: [:icon, :value]]
  end

  attributes do
    uuid_primary_key :id
    attribute :icon, :string, allow_nil?: false
    attribute :value, :string, allow_nil?: false
  end
end
