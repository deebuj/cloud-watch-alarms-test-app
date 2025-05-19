# CloudWatch Alarms Test Lambda API

This is a .NET Core Web API Lambda function that demonstrates CloudWatch logging capabilities.

## Prerequisites

- .NET 9.0 SDK
- AWS CLI configured with appropriate credentials
- Terraform CLI
- Docker (for local Lambda testing)

## Local Development

1. Clone the repository
2. Navigate to the project directory
```powershell
cd Lambda.Api
```
3. Restore dependencies
```powershell
dotnet restore
```
4. Run the application locally
```powershell
dotnet run
```

## Deployment

### Manual Deployment

1. Build and publish the application
```powershell
dotnet publish -c Release --runtime linux-x64 --self-contained false
```

2. Navigate to the Terraform directory
```powershell
cd ../terraform
```

3. Initialize Terraform
```powershell
terraform init
```

4. Plan the deployment
```powershell
terraform plan
```

5. Apply the changes
```powershell
terraform apply
```

### GitHub Actions Deployment

The project includes a GitHub Actions workflow that automatically deploys the application when changes are pushed to the main branch.

To enable GitHub Actions deployment:

1. Configure the following secrets in your GitHub repository:
   - `AWS_ROLE_ARN`: ARN of the IAM role to assume for deployment

2. Push your changes to the main branch, and the workflow will automatically deploy the application.

## API Endpoints

### POST /log/error
Logs an error message to CloudWatch

Example request:
```http
POST /log/error
Content-Type: application/json

"This is an error message"
```

## Infrastructure

The infrastructure is managed with Terraform and includes:
- Lambda function
- API Gateway
- CloudWatch Log Groups
- IAM roles and policies

## Monitoring

You can monitor the application through:
- CloudWatch Logs at `/aws/lambda/cloud-watch-alarms-test`
- API Gateway access logs
- CloudWatch Metrics for Lambda execution