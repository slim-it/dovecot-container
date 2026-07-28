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

The image tag is the upstream Dovecot version with the build number appended:
`<dovecot-upstream-version>.<build>`. Which versions a given tag actually
contains is recorded in its OCI labels, and in the two files above for the
current build.

## Why the tag does not name the plugin version

The obvious tag for an image with two independently moving inputs is
`<dovecot>-wormhole<plugin>`, which says exactly what is inside it. It was the
first scheme here and it is a trap, because of how tags are compared.

Everything after the first hyphen in a tag is read as a *variant* marker, not
as part of the version — the same mechanism that stops a consumer on
`-alpine` being offered `-slim`. A consumer pinned at `2.4.2-wormhole0.9` is
therefore only ever offered tags of the form `<newer>-wormhole0.9`. The moment
the plugin version moves, no such tag will ever be published again: this repo
builds exactly one image per state of `master`, so the tags form a single
sequence of adopted combinations, not a grid of every pairing. The consumer's
pin then has no candidates at all and simply stops receiving updates — with no
error, no warning, and an image that looks maintained precisely because nothing
is ever proposed for it.

Deriving the plugin half from this repository's files instead does not help:
that tells a consumer which plugin version exists upstream, not which image was
ever built, so it can confidently point a pin at a combination that was never
published.

A single ordered version has neither failure. Every tag is comparable with
every other, so a consumer is always offered the newest image that genuinely
exists, and falling behind is impossible rather than invisible. The build
number is the last component so that ordering holds no matter which input
moved — a plugin-only change still produces a strictly higher tag.

The image carries no configuration; `dovecot.conf` and the Sieve scripts are
mounted in by the consuming manifests. `curl` is present for the IMAPSieve
spam-training hooks, which post to rspamd's controller rather than pulling the
whole rspamd server in for its client binary.

## Image

CI publishes:

```text
ghcr.io/slim-it/dovecot-container:<dovecot-version>.<build>
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
