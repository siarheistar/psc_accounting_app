# Deploying the FastAPI Backend (Render)

This repo includes a Render blueprint (`render.yaml`) for one-click deploys.

## One-Click Deploy

Click this button to deploy on Render (free plan by default):

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy)

After clicking, choose this repository and Render will auto-detect `backend/render.yaml`.

## Manual Steps

1. Create a new Web Service on Render
2. Runtime: Docker
3. Repo: this repository, Root directory: `backend/`
4. Dockerfile: `backend/Dockerfile`
5. Health check path: `/health`
6. Set environment variables (DB creds, etc.) in Render Dashboard
7. Deploy

## Environment Variables

- `ENVIRONMENT=production`
- `DATABASE_URL` (if you prefer a single URL)
- Or use the individual DB vars your `database.py` expects

## Verify
- Once deployed, open `https://your-app.onrender.com/docs` to see Swagger
- Update Flutter base URL to the Render URL
- Ensure CORS origins include your hosting domain
