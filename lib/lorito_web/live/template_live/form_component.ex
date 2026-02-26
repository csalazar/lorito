defmodule LoritoWeb.TemplateLive.FormComponent do
  use LoritoWeb, :live_component

  alias Lorito.Templates

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage template records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="template-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />

        <.label>Copy payloads</.label>
        <div tabindex="0" class="collapse bg-base-200">
          <div class="collapse-title text-sm font-medium font-bold">What are copy payloads?</div>
          <div class="collapse-content font-medium text-sm">
            <p>
              A copy payload is a <a href="https://shopify.github.io/liquid/">Liquid template</a>
              in which the workspace URL (referenced as <code>workspace_url</code>) is inserted.
            </p>
            <br />
            <p>
              For instance, a copy payload for blind XSS would be <code>{"<script src=\"{{ workspace_url }}\"></script>"}</code>.
            </p>
            <br />
            <p>
              <u>Available filters</u>
              <ul>
                <li>
                  <code>http_protocol</code>: convert from <code>https</code> to <code>http</code>
                </li>
                <li>
                  <code>no_protocol</code>: remove protocol
                </li>
              </ul>
            </p>
          </div>
        </div>

        <.inputs_for :let={copy_payload_form} field={@form[:copy_payloads]}>
          <div class="flex flex-row space-x-4">
            <div class="w-1/4">
              <.input type="text" field={copy_payload_form[:name]} label="Name" class="w-3/12" />
            </div>
            <div class="w-full">
              <.input type="text" field={copy_payload_form[:value]} label="Value" />
            </div>
            <label>
              <input
                type="checkbox"
                name={"#{@form.name}[_drop_copy_payloads][]"}
                value={copy_payload_form.index}
                class="hidden"
              />

              <.icon name="hero-x-mark" />
            </label>
          </div>
        </.inputs_for>

        <label>
          <input
            type="checkbox"
            name={"#{@form.name}[_add_copy_payloads]"}
            value="end"
            class="hidden"
          />
          <.icon name="hero-plus" />
        </label>

        <:actions>
          <.button class="btn-primary" phx-disable-with="Saving...">Save Template</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{action: :new, current_user: current_user} = assigns, socket) do
    form = Templates.form_to_create_template(actor: current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(form))}
  end

  @impl true
  def update(%{action: :edit, template: template} = assigns, socket) do
    form = Templates.form_to_update_template(template)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => form_data}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: form_data) do
      {:ok, template} ->
        notify_parent({:saved, template})

        socket =
          socket
          |> put_flash(:info, "Template saved successfully")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> put_flash(:error, "Could not save template data")
          |> assign(:form, form)

        {:noreply, socket}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
