defmodule Lorito.ResponsesTest do
  use Lorito.DataCase

  alias Lorito.Responses
  import Lorito.AccountsFixtures
  import Lorito.WorkspacesFixtures
  import Lorito.TemplatesFixtures

  setup do
    owner = user_fixture()

    Lorito.Repo.put_user(owner)

    {:ok, owner: owner}
  end

  describe "responses" do
    alias Lorito.Responses.Response

    import Lorito.ResponsesFixtures

    @valid_attrs %{
      "status" => 200,
      "body" => "some body",
      "headers" => [],
      "route" => "route"
    }

    @invalid_attrs %{"route" => nil}

    test "list_responses/0 returns all responses" do
      response = response_fixture()
      assert Responses.list_responses() == [response]
    end

    test "get_response!/1 returns the response with given id" do
      response = response_fixture()
      assert Responses.get_response!(response.id) == response
    end

    test "create_response/2 with workspace creates a response in workspace" do
      workspace = workspace_fixture()

      assert {:ok, %Response{} = response} = Responses.create_response(@valid_attrs, workspace)
      assert response.status == 200
      assert response.body == "some body"
      assert response.headers == []
      assert response.route == "route"
      assert response.workspace_id == workspace.id
    end

    test "create_response/2 with template creates a response in template" do
      template = template_fixture()

      assert {:ok, %Response{} = response} = Responses.create_response(@valid_attrs, template)
      assert response.status == 200
      assert response.body == "some body"
      assert response.headers == []
      assert response.route == "route"
      assert response.template_id == template.id
    end

    test "create_response/2 with invalid data returns error changeset" do
      workspace = workspace_fixture()
      assert {:error, %Ecto.Changeset{}} = Responses.create_response(@invalid_attrs, workspace)
    end

    test "update_response/2 with valid data updates the response" do
      response = response_fixture()

      update_attrs = %{
        status: 500,
        body: "some updated body",
        headers: [],
        route: "new_route"
      }

      assert {:ok, %Response{} = response} = Responses.update_response(response, update_attrs)
      assert response.status == 500
      assert response.body == "some updated body"
      assert response.headers == []
      assert response.route == "new_route"
    end

    test "update_response/2 with invalid data returns error changeset" do
      response = response_fixture()
      assert {:error, %Ecto.Changeset{}} = Responses.update_response(response, @invalid_attrs)
      assert response == Responses.get_response!(response.id)
    end

    test "delete_response/1 deletes the response" do
      response = response_fixture()
      assert {:ok, %Response{}} = Responses.delete_response(response)
      assert_raise Ecto.NoResultsError, fn -> Responses.get_response!(response.id) end
    end

    test "change_response/1 returns a response changeset" do
      response = response_fixture()
      assert %Ecto.Changeset{} = Responses.change_response(response)
    end
  end
end
