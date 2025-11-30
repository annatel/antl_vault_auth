defmodule AntlVaultAuth.AntlVaultAuthTest do
  use ExUnit.Case, async: false

  alias AntlVaultAuth.AuthenticatedVaults

  setup do
    # AuthenticatedVaults.init() => a ets table of cache
    # is recreated at the begining of each test
    AuthenticatedVaults.init()
    {:ok, test_server} = TestServer.start()
    {:ok, test_server: test_server}
  end

  describe "auth/2" do
    test "when the cache contains an authenticated vault client for the credentials and the vault has the same options, returns the cached authenticated vault" do
      vault_client = new_vault_client()

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response = %{auth: %{client_token: "token1", lease_duration: 60}}

      expect_login_approle(credentials, valid_response)

      assert {:ok, authenticated_vault_client} = AntlVaultAuth.auth(vault_client, credentials)

      assert {:ok, ^authenticated_vault_client} = AntlVaultAuth.auth(vault_client, credentials)
    end

    test "when the cache contains an authenticated vault client for the credentials but with a different host, authenticates to the vault and save the vault client",
         %{test_server: server_1} do
           {:ok, server_2} = TestServer.start()

      vault_client_1 = new_vault_client(server_1)
      vault_client_2 = new_vault_client(server_2)

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response_1 = %{auth: %{client_token: "token1", lease_duration: 60}}
      valid_response_2 = %{auth: %{client_token: "token2", lease_duration: 60}}

      expect_login_approle(server_1, credentials, valid_response_1)
      expect_login_approle(server_2, credentials, valid_response_2)

      {:ok, authenticated_vault_client_1} = AntlVaultAuth.auth(vault_client_1, credentials)

      assert {:ok, authenticated_vault_client_2} =
               AntlVaultAuth.auth(vault_client_2, credentials)

      assert authenticated_vault_client_2.token != authenticated_vault_client_1.token

      assert {:ok, ^authenticated_vault_client_2} =
               AntlVaultAuth.auth(vault_client_2, credentials)
    end

    test "when the cache contains an authenticated vault client, authenticates to the vault with mismatched 'credentials type/auth method' parameters and get the 'Missing credentials' error" do
      vault_client_1 = new_vault_client()

      vault_client_2 = Map.replace!(vault_client_1, :auth, Vault.Auth.UserPass)

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response = %{auth: %{client_token: "token1", lease_duration: 60}}

      expect_login_approle(credentials, valid_response)

      {:ok, authenticated_vault_client_1} = AntlVaultAuth.auth(vault_client_1, credentials)

      assert {:error, ["Missing credentials - username and password are required.", ^credentials]} =
               AntlVaultAuth.auth(vault_client_2, credentials)

      assert {:ok, ^authenticated_vault_client_1} =
               AntlVaultAuth.auth(authenticated_vault_client_1, credentials)
    end

    test "when the cache contains an authenticated vault client for the 'auth method/credentials', authenticates to the vault with different 'auth method/credentials' and save the vault client" do
      vault_client_1 = new_vault_client()

      vault_client_2 = Map.replace!(vault_client_1, :auth, Vault.Auth.UserPass)

      credentials_1 = %{role_id: "role_id", secret_id: "secret_id"}

      credentials_2 = %{username: "username", password: "password"}

      valid_response_1 = %{auth: %{client_token: "token1", lease_duration: 60}}
      valid_response_2 = %{auth: %{client_token: "token2", lease_duration: 60}}

      expect_login_approle(credentials_1, valid_response_1)

      {:ok, authenticated_vault_client_1} = AntlVaultAuth.auth(vault_client_1, credentials_1)

      expect_login_userpass(credentials_2, valid_response_2)

      assert {:ok, authenticated_vault_client_2} =
               AntlVaultAuth.auth(vault_client_2, credentials_2)

      assert authenticated_vault_client_2.token != authenticated_vault_client_1.token

      assert {:ok, ^authenticated_vault_client_2} =
               AntlVaultAuth.auth(vault_client_2, credentials_2)
    end

    test "when the cache contains an authenticated vault client for the credentials but with a different engine, authenticates to the vault and save the vault client" do
      vault_client_1 = new_vault_client()

      vault_client_2 = Map.replace!(vault_client_1, :engine, Vault.Engine.KVV1)

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response_1 = %{auth: %{client_token: "token1", lease_duration: 60}}
      valid_response_2 = %{auth: %{client_token: "token2", lease_duration: 60}}

      expect_login_approle(credentials, valid_response_1)

      {:ok, authenticated_vault_client_1} = AntlVaultAuth.auth(vault_client_1, credentials)

      expect_login_approle(credentials, valid_response_2)

      assert {:ok, authenticated_vault_client_2} = AntlVaultAuth.auth(vault_client_2, credentials)

      assert authenticated_vault_client_2.token != authenticated_vault_client_1.token

      assert {:ok, ^authenticated_vault_client_2} =
               AntlVaultAuth.auth(vault_client_2, credentials)
    end

    test "when the cache contains an authenticated vault client for the credentials but with a different http client, authenticates to the vault and save the vault client" do
      defmodule TestHttpAdapter do
        def request(method, url, params, headers, http_options) do
          Vault.HTTP.Tesla.request(method, url, params, headers, http_options)
        end
      end

      vault_client_1 = new_vault_client()

      vault_client_2 = Map.replace!(vault_client_1, :http, TestHttpAdapter)

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response_1 = %{auth: %{client_token: "token1", lease_duration: 60}}
      valid_response_2 = %{auth: %{client_token: "token2", lease_duration: 60}}

      expect_login_approle(credentials, valid_response_1)

      {:ok, authenticated_vault_client_1} = AntlVaultAuth.auth(vault_client_1, credentials)

      expect_login_approle(credentials, valid_response_2)

      assert {:ok, authenticated_vault_client_2} = AntlVaultAuth.auth(vault_client_2, credentials)

      assert authenticated_vault_client_2.token != authenticated_vault_client_1.token

      assert {:ok, ^authenticated_vault_client_2} =
               AntlVaultAuth.auth(vault_client_2, credentials)
    end

    test "when the cache does not contains an authenticated vault client for the credentials, authenticates to the vault and save the  vault client" do
      vault_client = new_vault_client()

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response = %{auth: %{client_token: "token1", lease_duration: 60}}

      assert nil == AntlVaultAuth.AuthenticatedVaults.lookup(vault_client, credentials)

      expect_login_approle(credentials, valid_response)

      {:ok, authenticated_vault_client} = AntlVaultAuth.auth(vault_client, credentials)

      assert authenticated_vault_client ==
               AntlVaultAuth.AuthenticatedVaults.lookup(vault_client, credentials)
    end

    test "when the cache contains an authenticated vault client for the credentials, force authentication to the vault and save (in cache) the new vault client" do
      vault_client = new_vault_client()

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response = %{auth: %{client_token: "token1", lease_duration: 60}}
      expect_login_approle(credentials, valid_response)
      {:ok, authenticated_vault_client} = AntlVaultAuth.auth(vault_client, credentials)

      valid_response = %{auth: %{client_token: "token2", lease_duration: 60}}
      expect_login_approle(credentials, valid_response)

      {:ok, authenticated_vault_client_foced} =
        AntlVaultAuth.auth(vault_client, credentials, force: true)

      assert authenticated_vault_client.token != authenticated_vault_client_foced.token

      assert authenticated_vault_client_foced ==
               AntlVaultAuth.AuthenticatedVaults.lookup(vault_client, credentials)
    end
  end

  defp new_vault_client(instance \\ nil) do
    instance = instance || TestServer.get_instance()
    Vault.new(
      auth: Vault.Auth.Approle,
      engine: Vault.Engine.KVV2,
      http: Vault.HTTP.Tesla,
      host: TestServer.url(instance),
      json: Jason
    )
  end

  defp expect_login_approle(params, response),
    do: expect_login("/v1/auth/approle/login", params, response)

  defp expect_login_approle(instance, params, response),
    do: expect_login(instance, "/v1/auth/approle/login", params, response)

  defp expect_login_userpass(params, response),
    do: expect_login("/v1/auth/userpass/login/username", params, response)

  defp expect_login(url, params, response) do
    expect_login(TestServer.get_instance(), url, params, response)
  end

  defp expect_login(instance, url, params, response) do
    TestServer.add(instance, url,
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
