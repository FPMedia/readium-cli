# Deploying Readium CLI to Railway with S3

This repo documents how to deploy the upstream [`readium/cli`](https://github.com/readium/cli) repository to Railway using a fork, with publications stored in AWS S3. The fork contains the Railway configuration (`railway.toml`) while keeping the upstream codebase intact.

## Overview

The deployment uses:
- A **fork** of `readium/cli` that includes `railway.toml` for config-as-code
- **AWS S3** for storing EPUB publications
- **Railway** for hosting the Readium CLI server

## Step 1: Fork and Add railway.toml

1. **Fork the repository:**
   - Go to https://github.com/readium/cli
   - Click "Fork" to create your own fork
   - Note your fork's URL (e.g., `https://github.com/YOUR_USERNAME/cli`)

2. **Add railway.toml to your fork:**
   - Clone your fork locally
   - Copy `railway.toml` from this wrapper repo to the root of your fork
   - Update the `source` in `railway.toml` to point to your fork (optional, Railway will use the repo you connect)
   - Commit and push to your fork's default branch (likely `develop` or `main`)

## Step 2: Connect Railway to Your Fork

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

## Step 3: Set Up Upstream Tracking

In Railway UI, go to your service → Settings → Source:
- Under "Upstream Repo", set it to `readium/cli`
- This allows Railway to show when upstream updates are available
- Click "Check for updates" periodically to see if upstream has new commits

## Step 4: Configure S3 Environment Variables

In Railway UI, go to your service → Variables and add:

| Variable | Description | Example |
|----------|-------------|---------|
| `S3_ACCESS_KEY` | Your AWS access key ID | `AKIAIOSFODNN7EXAMPLE` |
| `S3_SECRET_KEY` | Your AWS secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `S3_ENDPOINT` | AWS S3 endpoint URL | `https://s3.amazonaws.com` or `https://s3.us-east-1.amazonaws.com` |
| `S3_REGION` | AWS region where your bucket is located | `us-east-1`, `eu-west-1`, etc. |
| `S3_BUCKET` | Your S3 bucket name (for reference) | `my-publications-bucket` |

**Note:** The `S3_BUCKET` variable is for documentation/reference only. The Readium CLI uses S3 URIs in the format `s3://bucket-name/path/to/file.epub` when accessing publications.

### S3 Endpoint Examples

- **Standard AWS S3:** `https://s3.amazonaws.com` (us-east-1 default)
- **Region-specific:** `https://s3.us-east-1.amazonaws.com`, `https://s3.eu-west-1.amazonaws.com`, etc.
- **S3-compatible services:** Use your service's endpoint URL

## Step 5: Verify Config-as-Code

1. In Railway UI, go to your service → Settings → Config-as-code
2. Railway should automatically detect `railway.toml` in your fork
3. Verify the settings match what's in your `railway.toml` file
4. The start command should include S3 flags with environment variable references, call the binary at `/opt/readium`, and use a single string like `"/bin/sh -c \"…\""` so Railway expands `$PORT` and other env vars.

## Step 6: Upload Publications to S3

Upload your EPUB files to your S3 bucket using one of these methods:

### Using AWS CLI:
```bash
aws s3 cp book.epub s3://your-bucket-name/publications/book.epub
```

### Using AWS Console:
1. Go to AWS S3 Console
2. Navigate to your bucket
3. Upload EPUB files (e.g., to a `publications/` prefix)

### S3 URI Format

Publications are accessed using S3 URIs in the format:
```
s3://bucket-name/path/to/file.epub
```

Example:
```
s3://my-publications-bucket/publications/hanis-assassin.epub
```

**Important:** Ensure your S3 bucket and objects have appropriate permissions. The IAM user/role associated with your `S3_ACCESS_KEY` needs at least `s3:GetObject` permission for the bucket and objects.

## Step 7: Deploy and Test

1. **Trigger deployment:**
   - Railway will automatically deploy when you push to your fork
   - Or manually trigger via Railway UI: Deployments → "Redeploy"

2. **Test accessing publications:**
   - Encode your S3 URI to base64url format
   - Access the manifest: `https://your-railway-url/{base64url-encoded-uri}/manifest.json`

### Example: Accessing a Publication

1. **S3 URI:** `s3://my-bucket/publications/book.epub`

2. **Encode to base64url:**
   ```bash
   echo -n "s3://my-bucket/publications/book.epub" | base64 | tr -d '=' | tr '/+' '_-'
   ```
   Result: `czM6Ly9teS1idWNrZXQvcHVibGljYXRpb25zL2Jvb2suZXB1Yg`

3. **Access manifest:**
   ```
   https://your-railway-url.railway.app/czM6Ly9teS1idWNrZXQvcHVibGljYXRpb25zL2Jvb2suZXB1Yg/manifest.json
   ```

4. **The manifest will contain links to all resources in the publication**

## Step 8: Keeping Your Fork Updated

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

For local development and testing, you can still use the local `publications/` folder:

```bash
docker run --rm \
  -p 15080:15080 \
  -v "$(pwd)/publications:/srv/publications" \
  readium-cli \
  serve -s file,http,https --address 0.0.0.0 \
  --port 15080 \
  --file-directory /srv/publications
```

Or use the helper script:
```bash
./scripts/run-local.sh
```

## Troubleshooting

### S3 Authentication Errors
- Verify your `S3_ACCESS_KEY` and `S3_SECRET_KEY` are correct
- Ensure the IAM user has `s3:GetObject` permissions
- Check that the bucket and objects exist

### S3 Endpoint Issues
- Verify `S3_ENDPOINT` matches your region (or use the standard endpoint)
- For non-AWS S3-compatible services, use the service's specific endpoint

### Publication Not Found
- Verify the S3 URI is correct (bucket name, path, file extension)
- Check that the file exists in S3 and is accessible with your credentials
- Ensure the base64url encoding is correct (no padding, URL-safe characters)

## Next Steps

- Set up automated syncing with upstream (GitHub Actions, etc.)
- Configure authentication mode (`-m jwt` or `-m jwks`) for production
- Set up monitoring and logging for your Railway service
- Consider using Railway's environment variables for different environments (staging/production)
