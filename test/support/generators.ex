defmodule Lorito.Test.Generators do
  use Ash.Generator

  def user(opts \\ []) do
    changeset_generator(Lorito.Accounts.User, :register,
      defaults: [
        email: Faker.Internet.email(),
        password: "password123"
      ],
      overrides: opts,
      authorize?: false
    )
  end

  def project(opts \\ []) do
    changeset_generator(Lorito.Projects.Project, :create,
      defaults: [
        name: Faker.App.name()
      ],
      overrides: opts,
      actor: opts[:actor]
    )
  end

  def workspace(opts \\ []) do
    changeset_generator(Lorito.Workspaces.Workspace, :create,
      defaults: [
        name: Faker.App.name(),
        project_id: opts[:project].id,
        template_id: nil,
        path: nil
      ],
      overrides: opts,
      actor: opts[:actor]
    )
  end

  def response(opts \\ []) do
    changeset_generator(Lorito.Responses.Response, :create,
      defaults: [
        status: 200,
        content_type: "text/html",
        body: Faker.Lorem.paragraph(),
        route: "test-route",
        workspace_id: opts[:workspace].id,
        template_id: nil,
        placeholders: [],
        headers: []
      ],
      overrides: opts,
      actor: opts[:actor]
    )
  end

  def template(opts \\ []) do
    changeset_generator(Lorito.Templates.Template, :create,
      defaults: [
        name: Faker.App.name(),
        copy_payloads: []
      ],
      overrides: opts,
      actor: opts[:actor]
    )
  end

  def integration(opts \\ []) do
    changeset_generator(Lorito.Logs.Integration, :create,
      defaults: [
        type: "discord",
        webhook_url: "https://discord.com/api/webhooks/#{Faker.UUID.v4()}/#{Faker.UUID.v4()}"
      ],
      overrides: opts,
      actor: opts[:actor]
    )
  end

  def log(opts \\ []) do
    changeset_generator(Lorito.Logs.Log, :create,
      defaults: [
        ip: Faker.Internet.ip_v4_address(),
        method: "GET",
        url: "https://example.com/test",
        headers: [],
        body: "",
        params: %{},
        workspace_id: opts[:workspace_id],
        project_id: opts[:project_id]
      ],
      overrides: opts,
      actor: opts[:actor]
    )
  end
end
