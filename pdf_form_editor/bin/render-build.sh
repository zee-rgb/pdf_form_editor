#!/usr/bin/env bash
# exit on error
set -o errexit

# Install gems
bundle install

# Precompile assets
bundle exec rake assets:precompile

# Build Tailwind CSS
bundle exec rails tailwindcss:build

# Clean assets (optional)
bundle exec rake assets:clean

# Run database migrations if DIRECT_DATABASE_URL is available for migrations
if [ -n "$DIRECT_DATABASE_URL" ]; then
  echo "Running database migrations with direct connection..."
  DATABASE_URL="$DIRECT_DATABASE_URL" bundle exec rails db:migrate
else
  echo "Running database migrations with pooled connection..."
  bundle exec rails db:migrate
fi
