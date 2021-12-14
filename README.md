# AntlVaultAuth

The Library to cached login into the Vault.
## Installation

The package can be installed by adding `antl_vault_auth` lib and additional requered packages to your list of dependencies in `mix.exs`

```elixir
def deps do
  [
    {:antl_vault_auth, git: "https://github.com/annatel/antl_vault_auth.git", tag: "0.1"}
    {:libvault, "~> 0.2.0"},
    {:tesla, "~> 1.3.0"},
    {:jason, ">= 1.0.0"}

  ]
end
```

After package are installed your must add it to the your Application supervision tree in the `application.ex` file.
There is two parameters you could pass as options to the `RefreshAuthTokenWorker`:

- `checkout_interval` - Checkout interval of the token expiration (seconds)
- `time_to_expiration` - Renewing of Token is allowed then the time before a token will be expired is less then typed here (seconds)

Your can skip this options. By default, the `checkout_interval` = 60 and `time_to_expiration` = 60 * 5.

```elixir
@impl true
def start(_type, _args) do
  children = [
    ...
    {AntlVaultAuth.RefreshAuthTokenWorker, [
      checkout_interval: 5,
      time_to_expiration: 55
    ]}
    ...
  ]

  opts = [strategy: :one_for_one, name: LibClient.Supervisor]
  Supervisor.start_link(children, opts)
end
```

## Usage

```elixir
options = [
  host: "http://127.0.0.1:8200",
  json: Jason,
  engine: Vault.Engine.KVV1,
  auth: Vault.Auth.Approle,
  http: Vault.HTTP.Tesla,
]

params = %{role_id: "role_id_1", secret_id: "secret_id_1"}

with vault <- Vault.new(options),
     {:ok, vault} <- AntlVaultAuth.Tokens.auth(vault, params)
do
  Vault.read(vault, "sims/#{icc_id}")
end

# output

{:ok,
 %{
   "phone_number" => "123-345-678-890",
   "blocked" => false,
   "code" => 123456,
   "provider" => "beeline"
   ...
   # etc...
 }}
```

## Tests

```elixir
mix test
```
