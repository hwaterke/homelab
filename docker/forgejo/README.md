# Forgejo

A private git origin for repositories that must not live on GitHub.
Deliberately small: no issues, no pull requests, no Actions runner, one user.

# Setup

## 1. Configure

```
cp example.env .env
```

Set `GIT_DOMAIN` to the hostname the reverse proxy serves. It is the name in
every clone URL, for both HTTPS and SSH.

## 2. Create the data directory

The container runs as the UID/GID in `compose.yaml` (1000:1000) and will not
start if it cannot write to `/data`:

```
mkdir -p appdata/forgejo
```

If you created it as another user:

```
chown -R 1000:1000 appdata/forgejo
```

## 3. Start it and complete the setup page

```
docker compose up -d
```

Then open the web UI and fill in the install form. Everything that matters is
pre-filled from `compose.yaml`, so the only section that needs attention is
**Administrator Account Settings** — create the account there. Registration is
disabled, so this is the only account that will ever exist; leaving the section
blank would instead promote the first user to register, which nobody can.

Completing the form writes `INSTALL_LOCK=true` into
`appdata/forgejo/gitea/conf/app.ini`, which is what closes the install page.

Forgejo also generates its own `SECRET_KEY` and `INTERNAL_TOKEN` into that file
on first start. Every `FORGEJO__*` variable in `compose.yaml` is re-applied to it
on each start, so `compose.yaml` stays the source of truth for everything it
sets.

## 4. Add an SSH key

In the web UI: avatar → Settings → SSH / GPG Keys → Add Key. This is what every
`git push` authenticates with; the account password is only for the web UI.

# Push to create

Pushing to a repository that does not exist creates it, private:

```
git remote add origin ssh://git@$GIT_DOMAIN:2222/<user>/<repo>.git
git push -u origin main
```

Nothing has to be created in the web UI first, and nothing is ever created
public.

# Where things live

Everything is under `appdata/forgejo/`, which is what the backup snapshots:

- `git/repositories/<user>/<repo>.git` — **plain bare git repositories.** They can
  be cloned with `git` alone, with no Forgejo running. That is the whole
  anti-lock-in claim, and it is worth verifying after a restore rather than
  believing it.
- `gitea/conf/app.ini` — configuration. The directory is named `gitea` for
  compatibility; `GITEA_CUSTOM` is baked into the image.
- `gitea/` — also holds the SQLite database.

Repositories copied in by hand appear under Site Administration → Repositories →
Unadopted, and are adopted from there. Adoption indexes them in place; it does
not rewrite or repack history.
