# <º\\\ lorito - HTTP security suite

![version](https://img.shields.io/github/v/tag/csalazar/lorito)

# What's this about?

Please read the [introduction blog post](https://csal.medium.com/introducing-lorito-a-security-http-suite-153c6df05516).

# Architecture

lorito is a web app written in Elixir
that uses a postgres database to store its information.
It provides a HTTP server to receive and respond HTTP requests.
Optionally, a DNS server can be configured to receive DNS requests.

# Running lorito

## Development

There's a [.devcontainer](https://containers.dev/) setup
to run lorito for development purposes,
which includes both an app container and a PostgreSQL container.

If you load this repository in [VSCode](https://code.visualstudio.com/),
it will detect the devcontainer setup
and prompt you to open the project inside a Docker container.

Once inside the container, run `mix add_user` to create a user.

Then, execute `mix phx.server` to run lorito at `http://localhost:4000`
and its dashboard is available at `http://localhost:4000/_lorito`.

## Production

To create a production-ready package,
a `Dockerfile` is used to build an [Elixir release](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-why-releases).

There are two prerequisites to run lorito:

- The postgres database must support SSL
- lorito must run over HTTPS because of the [Clipboard API](https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API#security_considerations)

lorito needs two secrets (environment variables) to work:

- `DATABASE_URL`: postgres connection URI of your database
- `SECRET_KEY_BASE`: the secret key to sign cryptographic material such as session tokens

### Using docker-compose

You can use [docker-compose](https://docs.docker.com/compose/) to run lorito
using the provided `docker-compose.yml` file.
To configure secrets,
create a [.env file](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/#env-file) to declare:

* `DATABASE_URL`: `postgresql://` connection URI
* `SECRET_KEY_BASE`: you can generate one with `head -c 66 /dev/urandom | base64 -w 0`
* `PHX_HOST`: `localhost` by default, then you can modify it with a custom domain.

`docker-compose up` will run lorito at `http://localhost:4000`
and its dashboard at `http://localhost:4000/_lorito`.

To add a user, follow this steps:
1. Enter into the container with `docker-compose exec elixir /bin/bash`
2. Run the database migrations with `./bin/migrate`
3. Then, enter IEX with `./bin/lorito remote`
4. Add your user with `Lorito.Release.add_user("email@domain.tld")`

### Using docker-compose with a postgres container

If you want to take a look at lorito, you can use this setup.
Beware that it uses default distro SSL keys to set up SSL
and [containers aren't recommended for production databases](https://vsupalov.com/database-in-docker/).

You can execute `docker-compose -f docker-compose.with-db.yml up`
and update `.env` with `DATABASE_URL=postgresql://postgres:postgres@db:5432/app`.

Then, follow the same instructions to add a user
as outlined in the previous section.

# Deployment

Root domains help keep URLs shorter.
However, they might receive a lot of automated requests.
Additionally, new lorito DNS capability
is complicated to set up at root level
due to several reasons (presence of DNS manager, other DNS records, etc).

Then, my suggestion is to use a subdomain to host lorito.

## Enabling the DNS server

lorito provides DNS capabilities to receive DNS requests.
The DNS server can be enabled at `https://subdomain.domain.tld/_lorito/settings`.
IP configuration is required to route the HTTP requests to your lorito instance.

To be able to receive DNS requests at `subdomain.domain.tld`,
you should add two DNS records in your DNS manager:

| Type | Name       | Content                   |
| ---- | ---------- | ------------------------- |
| NS   | subdomain  | ns1.domain.tld            |
| A    | ns1        | <subdomain.domain.tld IP> |

Once everything is setup and changes are propagated,
you can test with `dig A abc.subdomain.domain.tld`
and the DNS requests should appear on the main logs.

## SSL certificate

The SSL certificate should be emitted for `*.subdomain.domain.tld`
to respond successfully to HTTPS requests.

## fly.io

My suggestion is to go with [fly.io](https://fly.io).
It takes care of secrets, SSL certificates, custom domains, monitoring, etc.

There's a little guide [here](docs/fly_io_deployment.md).

# Troubleshooting

## We can't find the internet error & loading bar not finishing

The issue is that you're accessing lorito dashboard
from an IP/host different than `PHX_HOST` from `.env` file.
They must match and the issue should be resolved.
