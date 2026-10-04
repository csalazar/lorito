# Fly.io deployment

### Creating your Fly.io app and adjust settings

Run the following command to create your `fly.toml` file:

`flyctl launch --no-db --vm-memory 256 --generate-name --no-deploy`

Then, change the following lines in `fly.toml`:

* `force_https` from `true` to `false` to receive also HTTP requests
* `min_machines_running` from `0` to `1` to have a permanent instance
* add `swap_size_mb = 512` below `kill_signal` to avoid OOM issues

Eventually change `PHX_HOST` to a custom domain if you set one on fly.io.

### Setting secrets

There are two secrets to set:
* `SECRET_KEY_BASE`: already set in the previous step
* `DATABASE_URL`: a PostgreSQL connection URI to your database

To set the secret enter the following command:

`flyctl secrets set DATABASE_URL=postgres://...`

### Using a private database CA

If your database uses a private CA, download its PEM certificate
and configure the application to verify the database with it.
Add the path to the existing `[env]` section of your instance's `fly.toml`
(or create that section) and add a `[[files]]` entry:

```toml
[env]
  DATABASE_SSL_CA_FILE = "/tmp/lorito-db-ca.pem"

[[files]]
  guest_path = "/tmp/lorito-db-ca.pem"
  secret_name = "DATABASE_CA_CERT"
```

Fly requires a base64-encoded secret for `[[files]]` and writes its decoded
contents to `guest_path` when the Machine starts. Stage both the certificate
and verified mode before deploying, so existing Machines do not restart before
the file mapping is present:

```sh
flyctl secrets set --stage DATABASE_CA_CERT="$(base64 < /path/to/team-ca.pem | tr -d '\n')" DATABASE_SSL_VERIFY=true
flyctl deploy
```

Postgrex reads the file when connecting, so it must be readable by the
application (UID 10001). The hostname in `DATABASE_URL` must match the database
certificate. Do not set `DATABASE_SSL_VERIFY=false` with `DATABASE_SSL_CA_FILE`.

### Deploying

`flyctl deploy` deploys two instances by default.
If you want only 1, use option `--ha=false`.

You're ready to deploy with `flyctl deploy --ha=false`.

### Creating a user

Once the instance is up and running,
it's time to create a user to log in.

1. Connect to the instance using `flyctl ssh console`.
2. Enter IEX with `./bin/lorito remote`
3. Add your user with `Lorito.Release.add_user("email@domain.tld")`

The output contains your user and password.
Now you can log in at `https://domain.tld/_lorito`
with this credentials.


# Optional: DNS setup

In fly.io, UDP services must be declared in your `fly.toml` file.
Fly requires the same internal and external UDP port. Add the build argument
and environment setting to the existing `[build.args]` and `[env]` sections
(create `[build.args]` if absent), then add the UDP service below. The build
argument grants BEAM permission to bind privileged ports while keeping the
application running as UID `10001`.

```toml
[build.args]
  DNS_BIND_CAPABILITY = "true"

[env]
  DNS_PORT = "53"

[[services]]
  internal_port = 53
  protocol = "udp"
  [[services.ports]]
    port = 53
```

fly.io requires [a static IP for UDP services](https://fly.io/docs/networking/udp-and-tcp/).
Assign a static v4 and v6 IP to your fly.io machine
to be able to configure lorito DNS server correctly.
Then, please refer to the section "Enabling the DNS server"
in the main README.
