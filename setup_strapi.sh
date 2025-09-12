#!/bin/bash
# setup_strapi.sh (Corrected Version)

# --- Basic Setup and Dependencies ---
# Redirect stdout/stderr to a log file
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user data script..."
sudo apt-get update -y
sudo apt-get upgrade -y
# Install git, nginx, and other tools for the script
sudo apt-get install -y nginx git expect

# --- Node.js and PM2 Installation ---
echo "Installing Node.js and PM2..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install pm2 -g

# --- Clone Strapi Repository ---
# We clone into a temporary directory first
cd /home/ubuntu
echo "Cloning Strapi repository from ${strapi_repo_url}..."
git clone ${strapi_repo_url}
# Dynamically get the repo folder name
REPO_DIR=$(basename "${strapi_repo_url}" .git)
cd $REPO_DIR

# --- Strapi Configuration ---
echo "Configuring Strapi..."
npm install # Install all dependencies first to get strapi command

# Generate Strapi APP_KEYS and other secrets
echo "Generating Strapi secret keys..."
keys_output=$(npm run strapi generate)
app_keys=$(echo "$keys_output" | grep -o 'APP_KEYS=[^,]*' | awk -F= '{print $2}')
api_token_salt=$(echo "$keys_output" | grep -o 'API_TOKEN_SALT=[^,]*' | awk -F= '{print $2}')
admin_jwt_secret=$(echo "$keys_output" | grep -o 'ADMIN_JWT_SECRET=[^,]*' | awk -F= '{print $2}')
jwt_secret=$(echo "$keys_output" | grep -o 'JWT_SECRET=[^,]*' | awk -F= '{print $2}')

# Create the .env file with values from Terraform
echo "Creating .env file..."
cat <<EOF > .env
HOST=0.0.0.0
PORT=1337
APP_KEYS=$app_keys
API_TOKEN_SALT=$api_token_salt
ADMIN_JWT_SECRET=$admin_jwt_secret
JWT_SECRET=$jwt_secret
DATABASE_CLIENT=postgres
DATABASE_HOST=${db_host}
DATABASE_PORT=5432
DATABASE_NAME=${db_name}
DATABASE_USERNAME=${db_username}
DATABASE_PASSWORD='${db_password}'
DATABASE_SSL=false
AWS_ACCESS_KEY_ID=${aws_access_key_id}
AWS_ACCESS_SECRET=${aws_secret_access_key}
AWS_REGION=${aws_region}
AWS_BUCKET_NAME=${s3_bucket_name}
EOF

# Install production dependencies and AWS S3 provider
npm install --production
npm install @strapi/provider-upload-aws-s3

# --- Nginx Configuration ---
echo "Configuring Nginx reverse proxy..."
# The nginx_strapi.conf was copied by the Terraform provisioner to /home/ubuntu
sudo cp /home/ubuntu/nginx_strapi.conf /etc/nginx/sites-available/strapi
# **THIS IS THE CRITICAL FIX:** Create a symbolic link to enable the site
sudo ln -s -f /etc/nginx/sites-available/strapi /etc/nginx/sites-enabled/
# Remove the default Nginx page
sudo rm -f /etc/nginx/sites-enabled/default
# Test the Nginx configuration for syntax errors
sudo nginx -t
# Restart Nginx to apply the changes
sudo systemctl restart nginx

# --- Build and Launch Strapi ---
echo "Building Strapi for production..."
# Set correct ownership for the project directory
sudo chown -R ubuntu:ubuntu /home/ubuntu/$REPO_DIR
# Build the admin panel
NODE_ENV=production npm run build
# Start the application with PM2
echo "Starting Strapi with PM2..."
pm2 start npm --name strapi -- run start
# Ensure PM2 restarts on server reboot
pm2 startup
pm2 save

echo "User data script finished successfully!"