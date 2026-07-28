# dovecot-container

Dovecot image built from the Ubuntu packages with the
[wormhole](https://codeberg.org/errror/wormhole) replication plugin compiled in.

Dovecot dropped its replicator; wormhole restores it, so a pair of servers can
carry each user's mail to the other. It is packaged
nowhere, so it is built here from a pinned git tag against `dovecot-dev` of the
exact version the runtime stage installs — the plugin links against Dovecot's
internal ABI, so a version skew between the two fails when Dovecot loads the
plugin rather than when the image builds.

Two files pin the build, each tracked by Renovate on its own:

- `VERSION` — the packaged Dovecot version (the full apt version string).
- `WORMHOLE_VERSION` — the wormhole release tag, without the leading `v`.

CI derives the image tag from both, so a tag names exactly what is inside it:
`<dovecot-upstream-version>-wormhole<wormhole-version>`.

The image carries no configuration; `dovecot.conf` and the Sieve scripts are
mounted in by the consuming manifests. `curl` is present for the IMAPSieve
spam-training hooks, which post to rspamd's controller rather than pulling the
whole rspamd server in for its client binary.

## Image

CI publishes:

```text
ghcr.io/slim-it/dovecot-container:<dovecot-version>-wormhole<wormhole-version>
ghcr.io/slim-it/dovecot-container:latest
ghcr.io/slim-it/dovecot-container:sha-<git-sha>
```

## Build locally

```sh
docker build \
  --build-arg DOVECOT_VERSION="$(cat VERSION)" \
  --build-arg WORMHOLE_VERSION="$(cat WORMHOLE_VERSION)" \
  -t ghcr.io/slim-it/dovecot-container:local .
```

## Verifying a build

The settings this image is configured with are version-sensitive, so check the
config the fleet ships against the binary before trusting a version bump:

```sh
docker run --rm -v /path/to/dovecot.conf:/etc/dovecot/dovecot.conf:ro \
  ghcr.io/slim-it/dovecot-container:local doveconf -n
```

`doveconf` reports unknown settings and normalises the ones it understood.
