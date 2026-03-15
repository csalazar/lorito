defmodule Lorito.Logs.Log.LogImplementation do
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        http: [
          type: :struct,
          constraints: [instance_of: Lorito.Logs.HTTP]
        ],
        dns: [
          type: :struct,
          constraints: [instance_of: Lorito.Logs.DNS]
        ]
      ]
    ]
end

defmodule Lorito.Logs.Log.GetLogImplementation do
  use Ash.Resource.Calculation

  def load(_, _, _) do
    [:http_details, :dns_details]
  end

  def strict_loads?, do: false

  def calculate(records, _, _) do
    Enum.map(records, fn record ->
      cond do
        record.http_details ->
          %Ash.Union{type: :http, value: record.http_details}

        record.dns_details ->
          %Ash.Union{type: :dns, value: record.dns_details}

        true ->
          nil
      end
    end)
  end
end
