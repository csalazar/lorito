defmodule Lorito.Responses.Response.Header do
  use Ash.Resource,
    data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: [:name, :value], update: [:name, :value]]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :value, :string, allow_nil?: false
  end
end
