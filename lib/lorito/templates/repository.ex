defmodule Lorito.Templates.TemplateRepo do
  import Ecto.Query, warn: false
  alias Lorito.Repo

  alias Lorito.Templates.Template
  alias Lorito.Accounts.User

  def list_templates(_filters \\ %{}) do
    Repo.all(Template) |> Repo.preload(:user)
  end

  def get_template!(id), do: Repo.get!(Template, id) |> Repo.preload([:user, :responses])

  def create_template(attrs \\ %{}) do
    caller = User.get_user_from_process()

    %Template{}
    |> Template.changeset(attrs)
    |> User.put_user(caller)
    |> Repo.insert()
  end

  def update_template(%Template{} = template, attrs) do
    template
    |> Template.changeset(attrs)
    |> Repo.update()
  end

  def delete_template(%Template{} = template) do
    Repo.delete(template)
  end

  def change_template(%Template{} = template, attrs \\ %{}) do
    Template.changeset(template, attrs)
  end
end
