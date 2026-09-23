FROM --platform=$BUILDPLATFORM golang:1-bookworm@sha256:ee420c17fa013f71eca6b35c3547b854c838d4f26056a34eb6171bba5bf8ece4 AS builder
ARG BUILDARCH TARGETOS TARGETARCH
ARG NO_SNAPSHOT=false

# Install GoReleaser, busybox-static (/bin/sh for the Railway start command),
# and media-types (/etc/mime.types, copied into the distroless image below).
RUN apt-get update && apt-get install -y --no-install-recommends wget busybox-static media-types && rm -rf /var/lib/apt/lists/*
RUN wget --no-verbose "https://github.com/goreleaser/goreleaser/releases/download/v2.8.2/goreleaser_2.8.2_$BUILDARCH.deb"
RUN dpkg -i "goreleaser_2.8.2_$BUILDARCH.deb"

# Create and change to the app directory.
WORKDIR /app

# Retrieve application dependencies.
# This allows the container build to reuse cached dependencies.
# Expecting to copy go.mod and if present go.sum.
COPY go.* ./
RUN go mod download

# Copy local code to the container image.
COPY . ./

# Git metadata isn't available in Railway's BuildKit context, so ignore errors.
RUN git describe --tags --always || echo "Skipping git describe (no .git metadata)"

# RUN git lfs pull && ls -alh publications

# Run goreleaser
# Note: Cache mounts removed for Railway compatibility
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH GOAMD64=v2 GOARM=7 \
    goreleaser build --single-target --id readium --skip=validate $(case "$NO_SNAPSHOT" in yes|true|1) ;; *) echo "--snapshot";; esac) --output ./readium

# Run tests
# FROM builder AS tester
# RUN go test ./...

# Produces very small images
FROM gcr.io/distroless/static-debian12 AS packager

# busybox provides /bin/sh so the entrypoint script can expand Railway env vars.
COPY --from=builder /bin/busybox /bin/busybox
COPY --from=builder /bin/busybox /bin/sh

# Extra metadata
LABEL org.opencontainers.image.source="https://github.com/readium/cli"

# Distroless has no mime database. Go's mime package, and go-toolkit's
# mediatype fallback, read /etc/mime.types. Copy Debian's file from the
# builder instead of fetching it; the old pagure.io mailcap URL returns 404
# and fails the Railway build.
COPY --from=builder /etc/mime.types /etc/mime.types

# Add demo EPUBs to the container by default
# ADD --chown=nonroot:nonroot https://readium-playground-files.storage.googleapis.com/demo/moby-dick.epub /srv/publications/

# Copy built Go binary and the Railway entrypoint.
COPY --from=builder "/app/readium" /opt/readium
COPY --from=builder /app/scripts/railway-serve.sh /opt/railway-serve.sh

EXPOSE 15080

USER nonroot:nonroot

# Railway's generated domain reaches the container on $PORT. This script binds
# there. A service start command overrides this ENTRYPOINT, so leave it empty.
ENTRYPOINT ["/bin/sh", "/opt/railway-serve.sh"]