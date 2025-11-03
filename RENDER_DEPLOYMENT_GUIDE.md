# Render Deployment Guide

## Overview
This guide will help you deploy your Productivity Portal Backend to Render with persistent PostgreSQL database.

## ✅ Yes, Data Will Be Saved!
When users access your deployed link, **all data will be permanently saved** to the PostgreSQL database, including:
- User accounts and authentication
- Productivity entries
- Daily prods
- Suppliers
- CSV uploads
- Todos
- All other application data

## Prerequisites
- GitHub account with your repository pushed
- Render account (free tier works fine to start)

## Step-by-Step Deployment

### 1. Create PostgreSQL Database on Render

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click **"New +"** → **"PostgreSQL"**
3. Configure database:
   - **Name**: `productivity-portal-db` (or your choice)
   - **Database**: `productivity_portal_production`
   - **User**: Auto-generated
   - **Region**: Choose closest to your users
   - **PostgreSQL Version**: 16 (or latest)
   - **Plan**: Free tier is fine for development
4. Click **"Create Database"**
5. Wait for database to be ready (takes 1-2 minutes)
6. **Important**: Copy the **Internal Database URL** (looks like `postgresql://user:pass@hostname/dbname`)

### 2. Create Web Service on Render

1. Click **"New +"** → **"Web Service"**
2. Connect your GitHub repository
3. Configure service:
   - **Name**: `productivity-portal-be`
   - **Region**: Same as database
   - **Branch**: `main`
   - **Root Directory**: Leave empty (or `productivity-portal-be` if needed)
   - **Runtime**: `Ruby`
   - **Build Command**:
     ```bash
     bundle install; bundle exec rake db:migrate
     ```
   - **Start Command**:
     ```bash
     bundle exec puma -C config/puma.rb
     ```
   - **Plan**: Free tier

### 3. Configure Environment Variables

In your web service settings, go to **"Environment"** tab and add:

| Key | Value | Notes |
|-----|-------|-------|
| `DATABASE_URL` | (Internal Database URL from step 1) | From PostgreSQL service |
| `RAILS_ENV` | `production` | Required |
| `RAILS_MASTER_KEY` | (Your master key) | See below |
| `SECRET_KEY_BASE` | (Generate new) | See below |
| `GOOGLE_CLIENT_ID` | (Your Google OAuth ID) | For authentication |
| `GOOGLE_CLIENT_SECRET` | (Your Google OAuth Secret) | For authentication |
| `FRONTEND_URL` | `https://your-frontend-app.com` | Your React app URL |

#### Getting Your Master Key:
```bash
cat config/master.key
```
Copy the content and paste it as `RAILS_MASTER_KEY` value.

#### Generating SECRET_KEY_BASE:
```bash
bundle exec rails secret
```
Copy the output and use it as `SECRET_KEY_BASE` value.

### 4. Update CORS Configuration

Make sure your `config/initializers/cors.rb` allows your frontend URL:

```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV['FRONTEND_URL'] || 'http://localhost:3000'
    
    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

### 5. Update Google OAuth Redirect URIs

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **APIs & Services** → **Credentials**
3. Click your OAuth 2.0 Client ID
4. Add authorized redirect URIs:
   ```
   https://your-app-name.onrender.com/auth/google_oauth2/callback
   ```
5. Save changes

### 6. Deploy!

1. Click **"Create Web Service"** button
2. Render will automatically:
   - Install dependencies (`bundle install`)
   - Run migrations (`rake db:migrate`)
   - Start your Rails server
3. Wait for build to complete (3-5 minutes first time)
4. Your app will be live at `https://your-app-name.onrender.com`

## Database Management

### Running Migrations
Migrations run automatically on each deployment via the build command. If you need to run them manually:

1. Go to your web service on Render
2. Click **"Shell"** tab
3. Run:
   ```bash
   bundle exec rake db:migrate RAILS_ENV=production
   ```

### Seeding Database
To populate initial data:

1. Open Shell in your web service
2. Run:
   ```bash
   bundle exec rake db:seed RAILS_ENV=production
   ```

### Database Console
To access PostgreSQL directly:

1. Go to your PostgreSQL service on Render
2. Click **"Connect"** → **"External Connection"**
3. Use provided credentials with psql or any PostgreSQL client

## Data Persistence

### ✅ What IS Persistent:
- **PostgreSQL Database**: All data is permanently stored
  - User accounts
  - Productivity entries
  - Daily prods
  - Suppliers
  - All application records
- **Database survives**:
  - App restarts
  - Redeployments
  - Code updates

### ⚠️ What is NOT Persistent:
- **File uploads** (if using local storage)
  - Solution: Use cloud storage (AWS S3, Cloudinary, etc.)
- **Logs** (cleared periodically)
- **Local file system changes**

## Monitoring Your Deployment

### Logs
View logs in real-time:
1. Go to your web service
2. Click **"Logs"** tab
3. Monitor for errors or issues

### Metrics
- Check CPU and memory usage in **"Metrics"** tab
- Free tier has limitations (512 MB RAM)

## Common Issues & Solutions

### Issue: Build Fails
**Solution**: Check logs for specific error. Common causes:
- Missing gems in Gemfile
- Wrong Ruby version
- Database connection issues

### Issue: Database Connection Error
**Solution**: 
- Verify `DATABASE_URL` is set correctly
- Ensure database is in the same region
- Use Internal Database URL, not External

### Issue: CORS Errors
**Solution**:
- Update `FRONTEND_URL` environment variable
- Check `cors.rb` configuration
- Verify frontend is using correct backend URL

### Issue: OAuth Not Working
**Solution**:
- Verify Google OAuth redirect URIs include Render URL
- Check `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set
- Ensure cookies are configured correctly

## Upgrading Database

Free tier limitations:
- 1 GB storage
- Limited connections

To upgrade:
1. Go to PostgreSQL service settings
2. Click **"Upgrade"**
3. Choose a paid plan for more storage and connections

## Backup Strategy

### Manual Backup
```bash
# From your local machine with Render database credentials
pg_dump DATABASE_URL > backup_$(date +%Y%m%d).sql
```

### Automatic Backups
- Available on paid PostgreSQL plans ($7/month)
- Daily backups with point-in-time recovery

## Testing Your Deployment

### 1. Health Check
```bash
curl https://your-app-name.onrender.com/api/v1/current_user
# Should return 401 (unauthorized) if not logged in
```

### 2. Create Test User
- Try signing up via Google OAuth
- Verify user is created in database
- Check if user persists after app restart

### 3. Test All Endpoints
- Create productivity entries
- Upload CSV
- Create suppliers
- Verify all data is saved

### 4. Bootstrap Developer Account
**Important**: The first developer account is hardcoded for initial setup:
- Email: `jinjoolane@gmail.com`
- When this email signs in via Google OAuth:
  - Automatically set as **Developer** role
  - Automatically **approved** (bypasses pending status)
  - Can immediately access all features including User Management
- All other emails will:
  - Default to **Guest** role
  - Require approval from a developer

This bootstrap account can then approve other users and assign roles through the User Management interface.

## Production Checklist

- [ ] PostgreSQL database created
- [ ] `DATABASE_URL` configured
- [ ] `RAILS_MASTER_KEY` set
- [ ] `SECRET_KEY_BASE` generated and set
- [ ] Google OAuth credentials configured
- [ ] Google redirect URIs updated
- [ ] `FRONTEND_URL` set correctly
- [ ] CORS configured
- [ ] Database migrations ran successfully
- [ ] Seeds loaded (if needed)
- [ ] Test user account created
- [ ] All endpoints tested
- [ ] Frontend connected successfully

## Cost Estimate

### Free Tier (Good for Development/Testing):
- Web Service: $0/month (sleeps after 15 min inactivity)
- PostgreSQL: $0/month (1 GB storage, 90-day limit)

### Paid Tier (Production Ready):
- Web Service: $7/month (always on, no sleep)
- PostgreSQL: $7/month (automatic backups, more storage)
- **Total**: ~$14/month

## Important Notes

1. **Free tier sleeps**: Your app will spin down after 15 minutes of inactivity. First request after sleep takes ~30 seconds.

2. **Database limit**: Free PostgreSQL expires after 90 days. Upgrade to paid plan for permanent storage.

3. **Environment variables**: Never commit secrets to git. Always use Render's environment variables.

4. **Migrations**: Always test migrations locally before deploying to avoid production issues.

5. **Zero downtime**: Render automatically handles deployments with zero downtime on paid plans.

## Next Steps

After successful deployment:
1. Update your frontend to use production API URL
2. Set up monitoring/error tracking (e.g., Sentry, Rollbar)
3. Configure custom domain (if needed)
4. Set up CI/CD for automatic deployments
5. Plan for scaling as user base grows

## Support

- [Render Documentation](https://render.com/docs)
- [Render Community](https://community.render.com)
- [Rails Deployment Guide](https://guides.rubyonrails.org/deploying.html)
