# Deploying Readium CLI to Railway with Cloudflare R2

This repo documents how to deploy the upstream [`readium/cli`](https://github.com/readium/cli) repository to Railway using a fork, with publications stored in [Cloudflare R2](https://developers.cloudflare.com/r2/). The fork contains the Railway configuration (`railway.toml`) while keeping the upstream codebase intact.

R2 is S3-compatible, so the Readium CLI still uses the `s3` scheme and `s3://` URIs. The image entrypoint [`scripts/railway-serve.sh`](./scripts/railway-serve.sh) points the existing S3 flags at your R2 account endpoint and binds `0.0.0.0:$PORT`.

## Overview

The deployment uses:

- A **fork** of `readium/cli` that includes `railway.toml` for config-as-code
- **Cloudflare R2** for storing EPUB publications
- **Railway** for hosting the Readium CLI server

## Step 1: Create an R2 bucket and API token

1. In the Cloudflare dashboard, go to **R2 object storage** → **Overview**: [Open R2](https://dash.cloudflare.com/?to=/:account/r2/overview)
2. Create a bucket (for example `nicole-b-publications`).
3. Copy your **Account ID** from the R2 overview. The S3 API endpoint is:

   ```
   https://<ACCOUNT_ID>.r2.cloudflarestorage.com
   ```

   For an [EU-jurisdiction](https://developers.cloudflare.com/r2/reference/data-location/) bucket, use `https://<ACCOUNT_ID>.eu.r2.cloudflarestorage.com` instead.
4. Under **Account Details**, select **Manage** next to **API Tokens**, then create a token.
5. Grant **Object Read** if the server only streams publications, or **Object Read & Write** if you also upload with the same token.
6. Copy the **Access Key ID** and **Secret Access Key**. You will not be able to see the secret again.

See [R2 authentication](https://developers.cloudflare.com/r2/api/tokens/) for token types and scopes.

## Step 2: Fork and add railway.toml

1. **Fork the repository:**
   - Go to https://github.com/readium/cli
   - Click "Fork" to create your own fork
   - Note your fork's URL (e.g., `https://github.com/YOUR_USERNAME/cli`)

2. **Add railway.toml to your fork:**
   - Clone your fork locally
   - Copy `railway.toml` from this wrapper repo to the root of your fork
   - Update the `source` in `railway.toml` to point to your fork (optional, Railway will use the repo you connect)
   - Commit and push to your fork's default branch (likely `develop` or `main`)

## Step 3: Connect Railway to Your Fork

1. **Via Railway UI:**
   - Create a new project or go to your existing project
   - Click "New" → "GitHub Repo"
   - Select your fork of `readium/cli`
   - Railway will automatically detect `railway.toml` for config-as-code

2. **Via Railway CLI:**
   ```bash
   railway init --name readium-cli
   railway link
   # Then connect to your fork in the UI or use railway up with your fork URL
   ```

## Step 4: Set Up Upstream Tracking

In Railway UI, go to your service → Settings → Source:

- Under "Upstream Repo", set it to `readium/cli`
- This allows Railway to show when upstream updates are available
- Click "Check for updates" periodically to see if upstream has new commits

## Step 5: Configure R2 Environment Variables

In Railway UI, go to your service → Variables and add:

| Variable | Description | Example |
|----------|-------------|---------|
| `R2_ACCESS_KEY_ID` | Access Key ID from the R2 API token | `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `R2_SECRET_ACCESS_KEY` | Secret Access Key from the R2 API token | `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `R2_ENDPOINT` | R2 S3 API endpoint | `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` |
| `R2_ACCOUNT_ID` | Cloudflare account ID (for reference / building the endpoint) | `4793d734c0b8e484dfc37ec392b5fa8a` |
| `R2_BUCKET` | R2 bucket name (for reference) | `nicole-b-publications` |

**Note:** `R2_ACCOUNT_ID` and `R2_BUCKET` are for documentation and upload tooling only. The container entrypoint uses `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, and `R2_SECRET_ACCESS_KEY`. The Readium CLI accesses publications as `s3://bucket-name/path/to/file.epub`.

A local template lives in [`.env.example`](./.env.example). Copy it to `.env` for local testing; `.env` is gitignored.

The entrypoint also sets `--s3-region auto` (or `R2_REGION` when that variable is set) and `--s3-use-path-style`. R2 requires `region=auto`, and path-style addressing is required when the AWS SDK uses the account-level R2 endpoint.

## Step 6: Verify Config-as-Code

1. In Railway UI, go to your service → Settings → Config-as-code
2. Railway should automatically detect `railway.toml` in your fork
3. Verify the settings match what's in your `railway.toml` file
4. The start command in `railway.toml` is `/bin/sh /opt/railway-serve.sh`. On a Dockerfile service that command replaces `ENTRYPOINT`, so it has to be that script. The script binds `0.0.0.0:$PORT` and passes the R2 credentials. Any other start command that does not listen on `$PORT` makes the public URL return `502 Application failed to respond`.

## Step 7: Upload Publications to R2

Upload your EPUB files to your R2 bucket using one of these methods.

### Using Wrangler

```bash
npx wrangler r2 object put your-bucket-name/publications/book.epub --file ./book.epub
```

### Using the AWS CLI with the R2 endpoint

```bash
aws s3 cp book.epub s3://your-bucket-name/publications/book.epub \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

### Using the Cloudflare dashboard

1. Go to [R2 → Overview](https://dash.cloudflare.com/?to=/:account/r2/overview)
2. Open your bucket
3. Upload EPUB files (for example under a `publications/` prefix)

### Publication URI format

Publications are accessed using S3 URIs (R2 is S3-compatible):

```
s3://bucket-name/path/to/file.epub
```

Example:

```
s3://nicole-b-publications/publications/hanis-assassin.epub
```

The R2 API token associated with `R2_ACCESS_KEY_ID` needs at least **Object Read** on that bucket.

## Step 8: Deploy and Test

1. **Trigger deployment:**
   - Railway will automatically deploy when you push to your fork
   - Or manually trigger via Railway UI: Deployments → "Redeploy"

2. **Test accessing publications:**
   - Encode your S3 URI to base64url format
   - Access the manifest: `https://your-railway-url/webpub/{base64url-encoded-uri}/manifest.json`

### Example: Accessing a Publication

1. **Publication URI:** `s3://my-bucket/publications/book.epub`

2. **Encode to base64url:**
   ```bash
   echo -n "s3://my-bucket/publications/book.epub" | base64 | tr -d '=' | tr '/+' '_-'
   ```
   Result: `czM6Ly9teS1idWNrZXQvcHVibGljYXRpb25zL2Jvb2suZXB1Yg`

3. **Access manifest:**
   ```
   https://your-railway-url.railway.app/webpub/czM6Ly9teS1idWNrZXQvcHVibGljYXRpb25zL2Jvb2suZXB1Yg/manifest.json
   ```

4. **The manifest will contain links to all resources in the publication**

## Step 9: Keeping Your Fork Updated

When upstream `readium/cli` has updates, sync them into your fork:

```bash
cd readium-cli  # or wherever you cloned your fork
git remote add upstream https://github.com/readium/cli.git  # if not already added
git fetch upstream
git merge upstream/develop  # or 'main', depending on default branch
git push origin develop
```

Railway will automatically redeploy when you push to your fork.

## Local Testing

Serve from R2 locally with the same flags Railway uses:

```bash
set -a && source .env && set +a

./readium serve -s s3,http,https \
  --address 0.0.0.0 \
  --port 15080 \
  --s3-endpoint "$R2_ENDPOINT" \
  --s3-access-key "$R2_ACCESS_KEY_ID" \
  --s3-secret-key "$R2_SECRET_ACCESS_KEY" \
  --s3-region auto \
  --s3-use-path-style
```

Or serve from a local `publications/` folder without R2:

```bash
docker run --rm \
  -p 15080:15080 \
  -v "$(pwd)/publications:/srv/publications" \
  readium-cli \
  serve -s file,http,https --address 0.0.0.0 \
  --port 15080 \
  --file-directory /srv/publications
```

## Troubleshooting

### Image build fails while fetching mime types

The distroless image needs `/etc/mime.types`. That file is copied from the Debian builder (`media-types`). Do not `ADD` it from `pagure.io`; that URL returns 404 and Railway fails the build with `invalid response status 404`.

### R2 Authentication Errors

- Verify `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` are the S3 credentials from an [R2 API token](https://developers.cloudflare.com/r2/api/tokens/), not a general Cloudflare API token
- Confirm the token has at least **Object Read** on the bucket
- Check that the bucket and object keys exist

### R2 Endpoint Issues

- `R2_ENDPOINT` must be `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` (or the jurisdiction-specific host)
- The account ID is 32 hex characters, copied from the Cloudflare dashboard URL (`dash.cloudflare.com/<ACCOUNT_ID>/...`). A shortened ID makes TLS fail with `handshake failure` before any object is read
- Do not use `https://s3.amazonaws.com` or a regional AWS host
- The entrypoint passes `--s3-use-path-style` and `--s3-region auto`
- A `502 Application failed to respond` means the process is not accepting connections on the port Railway proxies to. The start command must be `/bin/sh /opt/railway-serve.sh` so the process binds `$PORT`

### Publication Not Found

- Verify the URI is `s3://bucket-name/path/to/file.epub` (scheme stays `s3`, not `r2`)
- Check that the file exists in R2 and is readable with your token
- Ensure the base64url encoding is correct (no padding, URL-safe characters)
- Manifests are under `/webpub/{encoded-uri}/manifest.json`

## Next Steps

- Set up automated syncing with upstream (GitHub Actions, etc.)
- Configure authentication mode (`-m jwt` or `-m jwks`) for production
- Set up monitoring and logging for your Railway service
- Consider using Railway's environment variables for different environments (staging/production)
