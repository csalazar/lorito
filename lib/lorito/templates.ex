defmodule Lorito.Templates do
  @moduledoc """
  The Templates context.
  """
  alias Lorito.Templates.TemplateRepo

  defdelegate list_templates(filters \\ %{}), to: TemplateRepo
  defdelegate get_template!(id), to: TemplateRepo
  defdelegate create_template(attrs \\ %{}), to: TemplateRepo
  defdelegate update_template(template, attrs \\ %{}), to: TemplateRepo
  defdelegate delete_template(template), to: TemplateRepo
  defdelegate change_template(template, attrs \\ %{}), to: TemplateRepo
end
