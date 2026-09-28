# Pin multi-platform base manifests; update versions and digests together.
ARG ELIXIR_VERSION=1.19.6
ARG OTP_VERSION=28.5.0.7
ARG DEBIAN_VERSION=trixie-20260918-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}@sha256:1db63b89c6cafefc3e00486495c0dfbf68dd38f3d9996fb6d2cfde691038aec7"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update -y && apt-get install -y --no-install-recommends build-essential git nodejs npm \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets
RUN cd assets && npm ci

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

ARG DNS_BIND_CAPABILITY=false

RUN apt-get update -y && \
  apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN groupadd --gid 10001 lorito \
    && useradd --uid 10001 --gid 10001 --no-create-home \
      --home-dir /var/lib/lorito --shell /usr/sbin/nologin lorito \
    && install -d -o 10001 -g 10001 -m 0700 /var/lib/lorito/tzdata

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=root:root /app/_build/${MIX_ENV}/rel/lorito ./

# Code is immutable to the runtime user. Only temp files and tzdata are writable.
RUN chmod -R a+rX,go-w /app

# Fly UDP requires matching internal/external ports. Grant only low-port binding
# to BEAM for that build; keep the default image compatible with cap_drop: ALL.
RUN case "$DNS_BIND_CAPABILITY" in \
      true) apt-get update -y \
        && apt-get install -y --no-install-recommends libcap2-bin \
        && setcap 'cap_net_bind_service=ep' /app/erts-*/bin/beam.smp \
        && getcap /app/erts-*/bin/beam.smp \
        && apt-get clean && rm -rf /var/lib/apt/lists/* ;; \
      false) ;; \
      *) echo "DNS_BIND_CAPABILITY must be true or false" >&2; exit 1 ;; \
    esac

ENV DNS_PORT=4053 \
    RELEASE_TMP=/tmp/lorito \
    TZDATA_DIR=/var/lib/lorito/tzdata \
    ERL_CRASH_DUMP=/tmp/erl_crash.dump

USER 10001:10001

CMD ["/app/bin/server"]
