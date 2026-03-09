# Release Process

This document explains how the automated release workflow operates and how to set it up for your own repository.

---

## How the Release Process Works

This project uses a **dual-branch model**:

- **`main`** — active development branch. All pull requests merge here.
- **`release`** — production branch. Contains the built `dist/index.js` and the current deployed version.

When a commit lands on `main`, the `release.yml` workflow runs automatically:

1. Builds `dist/index.js` from source
2. Computes a combined SHA-256 hash across `dist/index.js`, `package.json`, and `README.md`, then compares it to the hash stored in `.release-hash` on the `release` branch
3. If the hash is unchanged, the workflow exits early — no new release is created
4. If the hash changed, the workflow determines the version bump from the commit message (conventional commits: `feat!:` → major, `feat:` → minor, everything else → patch)
5. Pushes the new build, updated `package.json`, `README.md`, and `.release-hash` to the `release` branch
6. Creates a GitHub Release tagged at the new version
7. Bumps the version in `package.json` on `main` with a `[skip ci]` commit

The workflow requires a bot identity (GitHub App or PAT) with write access to both branches, because GitHub's branch protection rules block the default `GITHUB_TOKEN` from pushing to protected branches.

---

## Setting Up a GitHub App (Recommended)

GitHub Apps are preferred over PATs because they have a narrower, auditable scope and appear as a distinct identity in git history.

1. Go to **GitHub Settings > Developer Settings > GitHub Apps > New GitHub App**
2. Name it something project-specific (e.g., `myproject-bot`)
3. Set **Homepage URL** to your repository URL
4. Under **Permissions**, configure:
   - **Contents**: Read & Write
   - **Metadata**: Read-only
5. Under **Where can this app be installed?**, select **Only on this account** (for organization-owned apps, the option wording may differ slightly)
6. Click **Create GitHub App** and note the **App ID** shown on the app's settings page
7. Scroll down to **Private keys** and click **Generate a private key** — a `.pem` file will download
8. In the left sidebar, click **Install App** and install it on your repository
9. In your repository, go to **Settings > Secrets and variables > Actions** and add two secrets:
   - `BOT_APP_ID` — the App ID from step 6
   - `BOT_PRIVATE_KEY` — the full contents of the `.pem` file from step 7
10. In your repository, go to **Settings > Rules > Rulesets** (or **Branches** if using classic branch protection) and add the bot as a **bypass actor** for both the `main` and `release` branch rules. The bot will appear as `myproject-bot[bot]` in the actor list. If you see a **Rulesets** tab under **Rules**, use that (this is the newer approach). If you only see **Branch protection rules** under **Branches**, use that instead.

---

## Alternative: Using a Personal Access Token (PAT)

If you prefer not to create a GitHub App, a fine-grained PAT works as a fallback.

1. Go to **GitHub Settings > Developer Settings > Personal access tokens > Fine-grained tokens > Generate new token**
2. Set **Resource owner** to the account or org that owns the repository
3. Under **Repository access**, select your repository
4. Under **Permissions > Repository permissions**, set **Contents** to **Read and write**
5. Generate the token and copy it
6. In your repository, go to **Settings > Secrets and variables > Actions** and add the token as a secret (e.g., `RELEASE_PAT`)
7. In `.github/workflows/release.yml`, replace the **Generate app token** step with a direct assignment:

   ```yaml
   - name: Set token
     id: app-token
     run: echo "token=${{ secrets.RELEASE_PAT }}" >> $GITHUB_OUTPUT
   ```

   No further changes are needed — the rest of the workflow already references `steps.app-token.outputs.token`, which is the same output name used by the replacement step.

8. Grant the PAT bypass access in your branch protection rules the same way you would for a GitHub App (search for your GitHub username in the bypass actor list)

**Note:** GitHub Apps are preferred because the token is short-lived (expires after 1 hour), the identity is clearly distinct from a human user, and you can revoke access at the app level without rotating a personal token.

---

## Setting Up the Release Branch

The workflow expects a `release` branch to already exist before the first run.

```bash
git checkout -b release
git push -u origin release
```

The local `release` branch must also exist for the `admin/version` script to work. If you later clone the repo fresh, fetch the release branch locally:

```bash
git fetch origin release:release
```

Once the branch exists, set up branch protection:

- Require pull requests before merging (or restrict direct pushes to the bot only)
- Add the bot as a bypass actor so the workflow can push directly

The first time the workflow runs with actual runtime changes, it will create `.release-hash` on the `release` branch automatically. Subsequent runs use that file to detect whether a new release is needed.

---

## Manual Version Bumps

The `admin/version` script lets you bump the version manually across both branches without waiting for a CI run. This is an admin-only operation — it requires branch protection bypass credentials.

**Read current version:**

```bash
./admin/version
```

**Bump and commit locally:**

```bash
./admin/version patch    # 1.2.3 → 1.2.4
./admin/version minor    # 1.2.3 → 1.3.0
./admin/version major    # 1.2.3 → 2.0.0
./admin/version 2.0.0   # set explicit version
```

**Bump, commit, and push both branches:**

```bash
./admin/version patch --push
```

The script commits independently on both `main` and `release` to avoid merge conflicts from divergent `package.json` fields. It must be run from the `main` branch with a clean working tree and requires the local `release` branch to exist (`git fetch origin release:release` if needed).

Because this pushes directly to protected branches, you must have admin privileges or use credentials with bypass access configured.
