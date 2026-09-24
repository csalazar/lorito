defmodule Lorito.ApiKeysTest do
  use Lorito.DataCase
  import Lorito.Test.Generators

  test "creation requires an actor and expiration; keys belong to their actor" do
    expires = DateTime.add(DateTime.utc_now(), 3600)
    assert {:error, _} = Lorito.Accounts.create_api_key(%{expires_at: expires})
    user = generate(user())
    assert {:error, _} = Lorito.Accounts.create_api_key(%{}, actor: user)
    key = Lorito.Accounts.create_api_key!(%{expires_at: expires}, actor: user)
    assert key.user_id == user.id
    plaintext = key.__metadata__.plaintext_api_key
    assert is_binary(plaintext)
    stored = Ash.get!(Lorito.Accounts.ApiKey, key.id, actor: user)
    assert stored.api_key_hash != plaintext
    refute Map.has_key?(stored.__metadata__, :plaintext_api_key)
  end

  test "users can only list and revoke their own keys" do
    user = generate(user())
    other = generate(user())
    expires = DateTime.add(DateTime.utc_now(), 3600)
    own = Lorito.Accounts.create_api_key!(%{expires_at: expires}, actor: user)
    foreign = Lorito.Accounts.create_api_key!(%{expires_at: expires}, actor: other)
    assert Enum.map(Lorito.Accounts.list_api_keys!(actor: user), & &1.id) == [own.id]
    assert {:error, _} = Lorito.Accounts.destroy_api_key(foreign, actor: user)
    assert Ash.get!(Lorito.Accounts.ApiKey, foreign.id, actor: other)
    assert :ok = Lorito.Accounts.destroy_api_key(own, actor: user)
    assert [] = Lorito.Accounts.list_api_keys!(actor: user)
  end
end
