# checkrr-patched

A narrow patched build of [aetaric/checkrr](https://github.com/aetaric/checkrr).
The upstream image (`aetaric/checkrr:latest`, v3.6.1 at time of writing) ships
`locale/locale.en.toml` without the `NotificationsTelegramError` message key.
The Telegram notifier calls `go-i18n`'s `MustLocalize` for that key on the
error path; the missing entry causes the process to panic.

This repo's Dockerfile clones the pinned upstream release and appends the
missing stanza **only if it is absent**. Everything else — the build, the
runtime image, the entrypoint — mirrors upstream. There are no other source
modifications.

## Image

    ghcr.io/bazinfan/checkrr-patched:latest
    ghcr.io/bazinfan/checkrr-patched:<upstream-tag>

`:latest` always tracks the most recent upstream release that has been built
here. Pinned version tags (`:v3.6.1`, `:v3.7.0`, …) are published alongside.

## Automation

`.github/workflows/build.yml` runs daily at 06:00 UTC and on manual dispatch.
Each run:

1. Resolves the latest upstream release tag.
2. Skips the build if that tag is already published to GHCR.
3. Checks whether upstream's `locale/locale.en.toml` at that tag contains
   `NotificationsTelegramError`.
4. Builds and pushes the image otherwise.
5. **If upstream now contains the key**, sends a Telegram notification
   announcing that this fork is no longer needed.

## Retiring this fork

When the workflow Telegrams you that upstream contains the fix, switch the
relevant `image:` in your compose to `aetaric/checkrr:latest` and archive
this repository.

## Configuration

The workflow expects two repository secrets for the "patch redundant" alert:

| Secret              | Purpose                                  |
| ------------------- | ---------------------------------------- |
| `TELEGRAM_TOKEN`    | Bot token for `api.telegram.org`.        |
| `TELEGRAM_CHAT_ID`  | Chat ID (user or group) to message.      |

If the secrets are absent the build still runs; only the alert step is skipped.

## License

GPL-3.0, matching upstream.
