defmodule AntlVaultAuth.AntlVaultAuthTest do
  use ExUnit.Case, async: false

  alias AntlVaultAuth.AuthenticatedVaults

  setup do
    AuthenticatedVaults.init()
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  describe "auth/2" do
    test "when the cache contains an authenticated vault client for the credentials and the vault has the same options, returns the cached authenticated vault",
      %{bypass: bypass}
    do
      vault_client = default_vault_client(bypass.port)

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response = %{auth: %{client_token: "token1", lease_duration: 60}}

      expect_once_login(bypass, "/v1/auth/approle/login", credentials, valid_response)

      assert {:ok, authenticated_vault_client} = AntlVaultAuth.auth(vault_client, credentials)

      assert {:ok, ^authenticated_vault_client} = AntlVaultAuth.auth(vault_client, credentials)
    end

    test "when the cache contains an authenticated vault client for the credentials but with a different host, authenticates to the vault and save the vault client",
      %{bypass: bypass_1}
    do
      bypass_2 = Bypass.open()

      vault_client_1 = default_vault_client(bypass_1.port)

      vault_client_2 = Map.replace!(vault_client_1, :host, endpoint_url(bypass_2.port))

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response_1 = %{auth: %{client_token: "token1", lease_duration: 60}}
      valid_response_2 = %{auth: %{client_token: "token2", lease_duration: 60}}

      expect_once_login(bypass_1, "/v1/auth/approle/login", credentials, valid_response_1)
      expect_once_login(bypass_2, "/v1/auth/approle/login", credentials, valid_response_2)

      {:ok, authenticated_vault_client_1} = AntlVaultAuth.auth(vault_client_1, credentials)

      assert {:ok, authenticated_vault_client_2} =
              AntlVaultAuth.auth(vault_client_2, credentials)

      assert authenticated_vault_client_2.token != authenticated_vault_client_1.token

      assert {:ok, ^authenticated_vault_client_2} = AntlVaultAuth.auth(vault_client_2, credentials)

      Bypass.down(bypass_2)
    end

    test "when the cache contains an authenticated vault client, authenticates to the vault with mismatched 'credentials type/auth method' parameters and get the 'Missing credentials' error",
      %{bypass: bypass}
    do
      vault_client_1 = default_vault_client(bypass.port)

      vault_client_2 = Map.replace!(vault_client_1, :auth, Vault.Auth.UserPass)

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response = %{auth: %{client_token: "token1", lease_duration: 60}}

      expect_once_login(bypass, "/v1/auth/approle/login", credentials, valid_response)

      {:ok, authenticated_vault_client_1} = AntlVaultAuth.auth(vault_client_1, credentials)

      assert {:error, ["Missing credentials - username and password are required.", ^credentials]} =
            AntlVaultAuth.auth(vault_client_2, credentials)

      assert {:ok, ^authenticated_vault_client_1} = AntlVaultAuth.auth(authenticated_vault_client_1, credentials)
    end

    test "when the cache contains an authenticated vault client for the 'auth method/credentials', authenticates to the vault with different 'auth method/credentials' and save the vault client",
      %{bypass: bypass}
    do
      vault_client_1 = default_vault_client(bypass.port)

      vault_client_2 = Map.replace!(vault_client_1, :auth, Vault.Auth.UserPass)

      credentials_1 = %{role_id: "role_id", secret_id: "secret_id"}

      credentials_2 = %{username: "username", password: "password"}

      valid_response_1 = %{auth: %{client_token: "token1", lease_duration: 60}}
      valid_response_2 = %{auth: %{client_token: "token2", lease_duration: 60}}

      expect_once_login(bypass, "/v1/auth/approle/login", credentials_1, valid_response_1)

      {:ok, authenticated_vault_client_1} = AntlVaultAuth.auth(vault_client_1, credentials_1)

      expect_once_login(bypass, "/v1/auth/userpass/login/username", credentials_2, valid_response_2)

      assert {:ok, authenticated_vault_client_2} =
              AntlVaultAuth.auth(vault_client_2, credentials_2)

      assert authenticated_vault_client_2.token != authenticated_vault_client_1.token

      assert {:ok, ^authenticated_vault_client_2} = AntlVaultAuth.auth(vault_client_2, credentials_2)
    end

    test "when the cache contains an authenticated vault client for the credentials but with a different engine, authenticates to the vault and save the vault client",
      %{bypass: bypass}
    do
      vault_client_1 = default_vault_client(bypass.port)

      vault_client_2 = Map.replace!(vault_client_1, :engine, Vault.Engine.KVV1)

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response_1 = %{auth: %{client_token: "token1", lease_duration: 60}}
      valid_response_2 = %{auth: %{client_token: "token2", lease_duration: 60}}

      expect_once_login(bypass, "/v1/auth/approle/login", credentials, valid_response_1)

      {:ok, authenticated_vault_client_1} = AntlVaultAuth.auth(vault_client_1, credentials)

      expect_once_login(bypass, "/v1/auth/approle/login", credentials, valid_response_2)

      assert {:ok, authenticated_vault_client_2} = AntlVaultAuth.auth(vault_client_2, credentials)

      assert authenticated_vault_client_2.token != authenticated_vault_client_1.token

      assert {:ok, ^authenticated_vault_client_2} = AntlVaultAuth.auth(vault_client_2, credentials)
    end

    test "when the cache contains an authenticated vault client for the credentials but with a different http client, authenticates to the vault and save the vault client",
      %{bypass: bypass}
    do
      defmodule TestHttpAdapter do
        def request(method, url, params, headers, http_options) do
          Vault.HTTP.Tesla.request(method, url, params, headers, http_options)
        end
      end

      vault_client_1 = default_vault_client(bypass.port)

      vault_client_2 = Map.replace!(vault_client_1, :http, TestHttpAdapter)

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response_1 = %{auth: %{client_token: "token1", lease_duration: 60}}
      valid_response_2 = %{auth: %{client_token: "token2", lease_duration: 60}}

      expect_once_login(bypass, "/v1/auth/approle/login", credentials, valid_response_1)

      {:ok, authenticated_vault_client_1} = AntlVaultAuth.auth(vault_client_1, credentials)

      expect_once_login(bypass, "/v1/auth/approle/login", credentials, valid_response_2)

      assert {:ok, authenticated_vault_client_2} = AntlVaultAuth.auth(vault_client_2, credentials)

      assert authenticated_vault_client_2.token != authenticated_vault_client_1.token

      assert {:ok, ^authenticated_vault_client_2} = AntlVaultAuth.auth(vault_client_2, credentials)
    end

    test "when the cache does not contains an authenticated vault client for the credentials, authenticates to the vault and save the  vault client",
      %{bypass: bypass}
    do
      vault_client = default_vault_client(bypass.port)

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      valid_response = %{auth: %{client_token: "token1", lease_duration: 60}}

      assert nil == AntlVaultAuth.AuthenticatedVaults.lookup(vault_client, credentials)

      expect_once_login(bypass, "/v1/auth/approle/login", credentials, valid_response)

      {:ok, authenticated_vault_client} = AntlVaultAuth.auth(vault_client, credentials)

      assert authenticated_vault_client == AntlVaultAuth.AuthenticatedVaults.lookup(vault_client, credentials)
    end
  end

  defp default_vault_client(port) do
    Vault.new(
      auth: Vault.Auth.Approle,
      engine: Vault.Engine.KVV2,
      http: Vault.HTTP.Tesla,
      host: endpoint_url(port),
      json: Jason
    )
  end

  defp expect_once_login(bypass, url, params, response) do
    Bypass.expect_once(bypass, "POST", url, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      body = Jason.decode!(body, keys: :atoms!)
      assert body == Map.take(params, Map.keys(body))

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(response))
    end)
  end

  defp endpoint_url(port), do: "http://localhost:#{port}"

end
