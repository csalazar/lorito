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
