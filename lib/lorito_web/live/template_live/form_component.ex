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
              </ul>
            </p>
          </div>
        </div>

        <.inputs_for :let={copy_payload_form} field={@form[:copy_payloads]}>
          <input type="hidden" name="template[copy_payloads_sort][]" value={copy_payload_form.index} />
          <div class="flex flex-row space-x-4">
            <div class="w-1/4">
              <.input type="text" field={copy_payload_form[:name]} label="Name" class="w-3/12" />
            </div>
            <div class="w-full">
              <.input type="text" field={copy_payload_form[:value]} label="Value" />
            </div>
            <div class="w-1/12">
              <label>
                <input
                  type="checkbox"
                  name="template[copy_payloads_drop][]"
                  value={copy_payload_form.index}
                  class="hidden"
                />
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </label>
            </div>
          </div>
        </.inputs_for>

        <label class="block cursor-pointer">
          <input type="checkbox" name="template[copy_payloads_sort][]" class="hidden" />
          <.icon name="hero-plus-circle" class="w-5 h-5" /> add copy payload
        </label>

        <input type="hidden" name="template[copy_payloads_drop][]" />
        <:actions>
          <.button class="btn-primary" phx-disable-with="Saving...">Save Template</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{template: template} = assigns, socket) do
    changeset = Templates.change_template(template)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"template" => template_params}, socket) do
    changeset =
      socket.assigns.template
      |> Templates.change_template(template_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"template" => template_params}, socket) do
    save_template(socket, socket.assigns.action, template_params)
  end

  defp save_template(socket, :edit, template_params) do
    case Templates.update_template(socket.assigns.template, template_params) do
      {:ok, template} ->
        notify_parent({:saved, template})

        {:noreply,
         socket
         |> put_flash(:info, "Template updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_template(socket, :new, template_params) do
    case Templates.create_template(template_params) do
      {:ok, template} ->
        notify_parent({:saved, template})

        {:noreply,
         socket
         |> put_flash(:info, "Template created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
