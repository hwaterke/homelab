# Reactures

A static site, served by nginx from an image built elsewhere. Nothing here builds
it: the image arrives in the registry already tested, because the build runs the
typecheck, the linter and the test suite inside the Dockerfile. An image that
exists is an image that passed.

# Setup

## 1. Configure

```
cp example.env .env
```

Set `REGISTRY` to the registry that holds the image. Leave `REACTURES_TAG`
commented out; it exists only for rollbacks.

## 2. Start it

```
docker compose up -d
```

The image is public, so no `docker login` is needed to pull it.

# Deploying

`deploy.sh` is the whole deploy: pull, restart, show the result, then fetch the
site and fail if it does not answer. It is what CI runs, and it takes no
arguments — the key CI connects with is bound to this script as a forced command,
so nothing else can be run over that connection.

Run it by hand the same way:

```
./deploy.sh
```

# Rolling back

Every build is also tagged with its short commit sha. To go back to one:

```
REACTURES_TAG=<short sha>   # in .env
docker compose up -d
```

**Take the line out again once `latest` is fixed.** `deploy.sh` reads `.env` on
every run, so while the pin is there each new deploy re-deploys the pinned build
and reports success.
