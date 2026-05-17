# syntax=docker/dockerfile:1.7
#
# checkrr-patched — builds aetaric/checkrr from source and conditionally
# adds the missing `NotificationsTelegramError` locale stanza. Without it,
# go-i18n's MustLocalize panics the first time checkrr tries to emit a
# Telegram error message.
#
# The patch is the smallest possible change: it appends one stanza to
# locale/locale.en.toml ONLY IF the key is absent. Once upstream merges
# the fix, the patch step becomes a no-op and the resulting image is
# functionally identical to upstream — at which point this fork can be
# retired in favour of aetaric/checkrr.
#
# Build args:
#   CHECKRR_VERSION   — upstream git ref to build (tag or branch)
#   ALPINE_VERSION    — pinned for reproducible runtime
#   NODE_VERSION      — used only to build the React webserver bundle
#   GO_VERSION        — used only to compile the Go binary

ARG CHECKRR_VERSION=v3.6.1
ARG ALPINE_VERSION=3.20
ARG NODE_VERSION=22
ARG GO_VERSION=1.24

# --- source: clone upstream, conditionally apply the locale patch ------
FROM alpine:${ALPINE_VERSION} AS source
ARG CHECKRR_VERSION
RUN apk add --no-cache git
WORKDIR /src
RUN git clone --depth 1 --branch "${CHECKRR_VERSION}" \
        https://github.com/aetaric/checkrr.git .
RUN if ! grep -qE '^\[NotificationsTelegramError\]' locale/locale.en.toml; then \
        printf '\n[NotificationsTelegramError]\ndescription = "Error sending Telegram notification"\nother = "Error sending Telegram notification: {{.Error}}"\n' \
            >> locale/locale.en.toml; \
    fi

# --- frontend: build the React webserver bundle ------------------------
FROM node:${NODE_VERSION}-alpine AS frontend
WORKDIR /src/webserver
COPY --from=source /src/webserver/ ./
RUN npm install --legacy-peer-deps \
 && npm run build

# --- builder: compile the Go binary ------------------------------------
FROM golang:${GO_VERSION}-alpine AS builder
WORKDIR /src
COPY --from=source /src/ ./
COPY --from=frontend /src/webserver/build ./webserver/build
RUN CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /checkrr .

# --- runtime: mirrors upstream's Dockerfile layout ---------------------
FROM alpine:${ALPINE_VERSION}
RUN apk add --no-cache ffmpeg tzdata
COPY --from=builder /checkrr /checkrr
WORKDIR /
ENTRYPOINT ["/checkrr"]

ARG CHECKRR_VERSION
LABEL org.opencontainers.image.title="checkrr-patched" \
      org.opencontainers.image.description="aetaric/checkrr ${CHECKRR_VERSION} with the NotificationsTelegramError locale key added." \
      org.opencontainers.image.source="https://github.com/bazinfan/checkrr-patched" \
      org.opencontainers.image.url="https://github.com/aetaric/checkrr" \
      org.opencontainers.image.licenses="GPL-3.0" \
      org.opencontainers.image.version="${CHECKRR_VERSION}"
