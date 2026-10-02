# Finance Tracker

One Node container that serves the API and the web app behind its own login. The
image is built elsewhere and arrives in the registry already tested, because the
build runs the typecheck, the linters and the test suite inside the Dockerfile. An
image that exists is an image that passed.

`appdata/` holds the app's data, today the price cache. It has no backup: all of it
can be fetched again.

# Setup

## 1. Configure

```
cp example.env .env
chmod 600 .env
```

Set `REGISTRY` to the registry that holds the image. Leave `FINANCE_TRACKER_TAG`
commented out; it exists only for rollbacks.

The three login secrets are made in a checkout of the app repo:

| Key | Made with |
| --- | --- |
| `PASSWORD_HASH` | `pnpm hash-password` |
| `SESSION_SECRET` | `openssl rand -base64 32` |
| `API_TOKEN_HASH` | `pnpm new-token`, which also prints the token for API clients |

Changing `SESSION_SECRET` logs every browser out. Changing `API_TOKEN_HASH` cuts off
every client that holds the old token.

## 2. Create the data folder

```
mkdir appdata
```

Do this before the first start. Docker creates a missing bind source as root, and
the app runs as uid 1000, so it could not write there.

## 3. Start it

```
docker compose up -d
```

The image is public, so no `docker login` is needed to pull it.

# Deploying

`deploy.sh` is the whole deploy: pull, restart, show the result, then call the
health route and fail if it does not answer. It is what CI runs, as
`deploy finance-tracker` through the deploy dispatcher.

Run it by hand the same way:

```
./deploy.sh
```

# Rolling back

Every build is also tagged with its short commit sha. To go back to one:

```
FINANCE_TRACKER_TAG=<short sha>   # in .env
docker compose up -d
```

**Take the line out again once `latest` is fixed.** `deploy.sh` reads `.env` on
every run, so while the pin is there each new deploy re-deploys the pinned build
and reports success.
