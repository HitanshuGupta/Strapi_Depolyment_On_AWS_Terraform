# Automated Strapi Deployment on AWS with Terraform

This repository contains a complete Infrastructure as Code (IaC) solution for deploying a production-ready, secure, and scalable Strapi CMS on AWS. The entire infrastructure is defined using **Terraform** and the server configuration is automated with a **shell script**.

This setup is designed to be a robust starting point for any Strapi project, handling networking, security, database, file storage, and application hosting automatically.

-----

## 🏛️ Architecture

This project provisions a secure and scalable architecture within a custom AWS VPC:

  * **VPC:** A logically isolated network with public and private subnets across two Availability Zones for high availability.
  * **Application Load Balancer (ALB):** Sits in the public subnets, receives all public traffic, handles health checks, and forwards requests to the Strapi EC2 instance. This is the single entry point to the application.
  * **EC2 Instance (Strapi Server):** A virtual server running in a **private subnet**, making it inaccessible from the public internet. It hosts the Strapi application and an Nginx reverse proxy.
  * **Bastion Host:** A small EC2 instance in a **public subnet** that acts as a secure "jump server," providing SSH access to the private Strapi instance for maintenance.
  * **RDS for PostgreSQL:** A fully managed, highly available PostgreSQL database running in the **private subnets**, ensuring it can only be accessed by the Strapi application.
  * **S3 Bucket:** Used for storing all media uploads, keeping the Strapi application stateless and making it easy to scale or redeploy.
  * **IAM:** An IAM user with tightly restricted permissions is created to allow the Strapi application to upload files to the S3 bucket securely.

-----

## ✨ Features

  * **Secure by Design:** Resources are isolated in private subnets with carefully configured security groups.
  * **Production-Ready:** Uses PM2 to manage the Strapi process, Nginx as a reverse proxy, and a managed RDS database.
  * **Automated Setup:** From networking to application configuration, the entire deployment is handled by Terraform and a single user-data script.
  * **Scalable:** Offloads media to S3 and uses a managed database, making it easy to scale the application horizontally in the future.

-----

## 📋 Prerequisites

Before you begin, ensure you have the following installed and configured:

1.  **An AWS Account:** With IAM permissions to create the resources defined in this project.
2.  **Terraform CLI:** [Install Terraform](https://developer.hashicorp.com/terraform/downloads)
3.  **AWS CLI:** [Install AWS CLI](https://aws.amazon.com/cli/) and configured with your credentials (`aws configure`).
4.  **An EC2 Key Pair:** Create an EC2 Key Pair in the AWS region you plan to deploy to. Download the `.pem` file.
5.  **A Strapi Project in a Git Repository:** Your Strapi application's source code must be hosted in a Git repository (e.g., on GitHub).

-----

## 🚀 Deployment Steps

### Step 1: Clone This Repository

Clone this repository to your local machine.

```bash
git clone <URL_of_this_repo>
cd <repo_name>
```

### Step 2: Configure Your Strapi Application

For this automated deployment to work, your Strapi project's Git repository **must** contain the following configuration files.

1.  **`.gitignore`**: Ensure you have a `.gitignore` file that excludes `node_modules`, `build`, `dist`, and `.env` files.

2.  **Production Database Config (`config/env/production/database.ts`)**:

    ```typescript
    // config/env/production/database.ts
    export default ({ env }) => ({
      connection: {
        client: 'postgres',
        connection: {
          host: env('DATABASE_HOST'),
          port: env.int('DATABASE_PORT', 5432),
          database: env('DATABASE_NAME'),
          user: env('DATABASE_USERNAME'),
          password: env('DATABASE_PASSWORD'),
          ssl: {
            rejectUnauthorized: false,
          },
        },
        debug: false,
      },
    });
    ```

3.  **Production S3 Provider Config (`config/env/production/plugins.ts`)**:

    ```typescript
    // config/env/production/plugins.ts
    export default ({ env }) => ({
      upload: {
        config: {
          provider: 'aws-s3',
          providerOptions: {
            accessKeyId: env('AWS_ACCESS_KEY_ID'),
            secretAccessKey: env('AWS_ACCESS_SECRET'),
            s3Options: {
              region: env('AWS_REGION'),
              params: {
                ACL: 'public-read',
                Bucket: env('AWS_BUCKET_NAME'),
              },
            },
          },
        },
      },
    });
    ```

4.  **PM2 Ecosystem File (`ecosystem.config.js`)**: Create this file in the root of your Strapi project.

    ```javascript
    // ecosystem.config.js
    module.exports = {
      apps: [
        {
          name: 'strapi',
          script: 'npm',
          args: 'start',
          env_production: {
            NODE_ENV: 'production',
          },
        },
      ],
    };
    ```

### Step 3: Configure Terraform Variables

Create a file named `terraform.tfvars` and fill in your specific details.

```hcl
# terraform.tfvars

aws_region      = "ap-south-1" # Your target AWS Region
project_name    = "my-strapi-app" # A unique name for your project
key_name        = "my-aws-key" # The name of your EC2 Key Pair
my_ip_address   = "192.0.2.123/32" # Your public IP for SSH access to the bastion host
strapi_repo_url = "https://github.com/YourUsername/YourStrapiRepo.git"

# --- Database Credentials ---
db_username     = "strapiadmin"
db_password     = "ChooseAStrongPassword123!"

# --- EC2 Instance Sizes ---
instance_type       = "t3.medium" # Recommended size for the build process
db_instance_class   = "db.t3.micro"
```

### Step 4: Deploy with Terraform

Run the following commands in your terminal:

```bash
# Initialize Terraform
terraform init

# (Optional) See what Terraform will create
terraform plan

# Apply the configuration and create the infrastructure
terraform apply --auto-approve
```

The deployment process will take 10-15 minutes.

### Step 5: Access Your Application

Once the deployment is complete, Terraform will output the DNS name of the Application Load Balancer.

```
Outputs:

alb_dns_name = "my-strapi-app-alb-1234567890.ap-south-1.elb.amazonaws.com"
```

Navigate to this URL in your browser. To create your first admin user, go to `http://<your_alb_dns_name>/admin`.

-----

## 💡 How It Works

  * **Terraform (`main.tf`)**: This file defines all the AWS resources. It creates the networking, security groups, RDS database, S3 bucket, IAM user, and EC2 instances.
  * **The Magic of `templatefile`**: The `aws_instance` resource for the Strapi server uses Terraform's `templatefile` function. This function reads the `setup_strapi.sh` script and injects values into it *before* the server is created. For example, it gets the endpoint address from the newly created RDS database and inserts it into the script. This is how the server knows how to connect to the database without any manual steps.
  * **The Setup Script (`setup_strapi.sh`)**: This script runs automatically when the Strapi EC2 instance first boots up. It performs the following tasks:
    1.  Installs Node.js, Nginx, and PM2.
    2.  Creates a swap file to prevent out-of-memory errors during the build.
    3.  Clones your Strapi application from your Git repository.
    4.  Generates all necessary Strapi security keys (`APP_KEYS`, etc.) using `openssl`.
    5.  Creates the `.env` file and populates it with the secrets and resource details passed in by Terraform.
    6.  Configures Nginx as a reverse proxy to forward traffic from port 80 to the Strapi app on port 1337.
    7.  Runs `npm run build` to compile the Strapi admin panel for production.
    8.  Uses the `ecosystem.config.js` file to start the application with PM2 in production mode.
    9.  Configures the PM2 service to auto-restart on server reboot.

-----

## 🔧 Troubleshooting

  * **502 Bad Gateway Error:** This usually means the Strapi application is not running. SSH into the server via the bastion host and check the application logs with `sudo pm2 logs strapi`.
  * **SSH Access:** To connect to your private Strapi instance for debugging:
    1.  First, SSH into the bastion host: `ssh -i "your-key.pem" ubuntu@<BASTION_PUBLIC_IP>`
    2.  From the bastion, SSH into the Strapi instance: `ssh -i "your-key.pem" ubuntu@<STRAPI_PRIVATE_IP>`
        (You'll need to copy your `.pem` key to the bastion host first).

-----

## 💣 Destroying the Infrastructure

To tear down all the created resources and avoid incurring further costs, run the following command:

```bash
terraform destroy --auto-approve
```