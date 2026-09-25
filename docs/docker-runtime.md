# Docker runtime

The image runs as UID/GID `10001:10001`, with root-owned application files in
`/app`. Compose adds a read-only filesystem, drops all capabilities, and enables
`no-new-privileges`.

## Ports

Update existing deployments to map external DNS port 53 to internal port 4053:

```yaml
ports:
  - "53:4053/udp"
  - "4000:4000"
```

For Fly, set `DNS_PORT=4053` and the UDP service's `internal_port = 4053`, keeping
external `port = 53`. Outside Docker, `DNS_PORT` defaults to 53.

## Writable mounts

Compose provides these tmpfs mounts with `noexec,nosuid,nodev`:

| Path | Purpose | Settings |
| --- | --- | --- |
| `/tmp` | Release configuration and crash dumps | 64 MiB, mode 1777 |
| `/var/lib/lorito/tzdata` | Timezone updates | 32 MiB, UID/GID 10001, mode 0700 |

Other read-only deployments must provide equivalent mounts. Timezone data is
seeded automatically; use a volume owned by UID/GID 10001 to retain updates
across restarts.

## Maintenance

Update base-image versions and digests together, preserving AMD64/ARM64 support.
Assets use `npm ci`. Supply secrets at runtime, never through build arguments.

After upgrading, verify migrations, HTTP, DNS, timezone loading, and graceful
shutdown on both architectures.
