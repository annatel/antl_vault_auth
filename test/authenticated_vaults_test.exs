defmodule AntlVaultAuth.AuthenticatedVaultsTest do
  use ExUnit.Case, async: false

  alias AntlVaultAuth.AuthenticatedVaults

  setup do
    AuthenticatedVaults.init()
    TestServer.start()
    :ok
  end

  describe "login_all/1" do
    test "when the cache contains an authenticated vault clients with different time to expiration, call to login_all/1 must update one of them" do
      credentials_1 = %{role_id: "role_id", secret_id: "secret_id"}
      credentials_2 = %{role_id: "role_id_2", secret_id: "secret_id_2"}

      valid_response_1 = %{auth: %{client_token: "token1", lease_duration: 60}}
      valid_response_2 = %{auth: %{client_token: "token2", lease_duration: 10}}
      valid_response_2_updated = %{auth: %{client_token: "token3", lease_duration: 10}}

      vault_client_1 = new_vault_client()
      vault_client_2 = new_vault_client()

      assert nil == AuthenticatedVaults.lookup(vault_client_1, credentials_1)
      assert nil == AuthenticatedVaults.lookup(vault_client_2, credentials_2)

      expect_login(credentials_1, valid_response_1)

      assert {:ok, authenticated_vault_client_1} =
               AntlVaultAuth.auth(vault_client_1, credentials_1)

      expect_login(credentials_2, valid_response_2)

      assert {:ok, authenticated_vault_client_2} =
               AntlVaultAuth.auth(vault_client_2, credentials_2)

      assert authenticated_vault_client_1 ==
               AuthenticatedVaults.lookup(vault_client_1, credentials_1)

      assert authenticated_vault_client_2 ==
               AuthenticatedVaults.lookup(vault_client_2, credentials_2)

      expect_login(credentials_2, valid_response_2_updated)
      AuthenticatedVaults.login_all(11)

      assert authenticated_vault_client_1 ==
               AuthenticatedVaults.lookup(vault_client_1, credentials_1)

      assert authenticated_vault_client_2_updated =
               AuthenticatedVaults.lookup(vault_client_2, credentials_2)

      assert authenticated_vault_client_2_updated.token != authenticated_vault_client_2.token

      assert expires_later_than?(
               authenticated_vault_client_2_updated,
               authenticated_vault_client_2
             )
    end
  end

  defp expires_later_than?(%Vault{} = l, %Vault{} = r) do
    :gt == NaiveDateTime.compare(l.token_expires_at, r.token_expires_at)
  end

  defp new_vault_client() do
    Vault.new(
      auth: Vault.Auth.Approle,
      engine: Vault.Engine.KVV2,
      http: Vault.HTTP.Tesla,
      host: TestServer.url(),
      json: Jason
    )
  end

  defp expect_login(params, response) do
    TestServer.add("/v1/auth/approle/login",
      via: :post,
      to: fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(body, keys: :atoms!)
        assert body == Map.take(params, Map.keys(body))

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end
    )
  end
end
