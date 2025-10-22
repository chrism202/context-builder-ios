# Context Builder - Cloud Setup Guide

This guide will help you set up the cloud backend and configure the iOS app to sync with it.

## Overview

The cloud integration adds:
- ☁️ Upload saved context to AWS cloud storage
- 🤖 MCP server to serve your context to AI assistants (Claude, etc.)
- 🔄 Sync across devices (future enhancement)

## Architecture

```
iOS App → API Gateway → Lambda Functions → DynamoDB + S3
                            ↓
                       MCP Server (for AI assistants)
```

## Prerequisites

### For Backend Deployment

- AWS Account ([Create one](https://aws.amazon.com/free/))
- AWS CLI ([Install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- AWS SAM CLI ([Install guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html))
- Node.js 20.x or later ([Download](https://nodejs.org/))

### For iOS App

- macOS with Xcode 15+
- iOS 16.0+ device or simulator

## Step-by-Step Setup

### 1. Deploy Backend to AWS

#### 1.1 Configure AWS CLI

```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Output format: `json`

#### 1.2 Install Backend Dependencies

```bash
cd backend
npm install
```

#### 1.3 Build the Backend

```bash
npm run build
```

#### 1.4 Deploy to AWS

```bash
sam deploy --guided
```

Answer the prompts:
- **Stack Name**: `context-builder-stack`
- **AWS Region**: Your preferred region (e.g., `us-east-1`)
- **Parameter Stage**: `dev`
- **Confirm changes before deploy**: `Y`
- **Allow SAM CLI IAM role creation**: `Y`
- **Disable rollback**: `N`
- **Save arguments to configuration file**: `Y`
- **SAM configuration file**: `samconfig.toml`
- **SAM configuration environment**: `default`

#### 1.5 Note the API Endpoint

After deployment completes, you'll see outputs like:

```
CloudFormation outputs from deployed stack
----------------------------------------------------------------
Outputs
----------------------------------------------------------------
Key                 ApiEndpoint
Description         HTTP API endpoint URL
Value               https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev

Key                 McpServerUrl
Description         MCP Server Function URL
Value               https://abc123xyz.lambda-url.us-east-1.on.aws/
----------------------------------------------------------------
```

**Copy the `ApiEndpoint` value** - you'll need it for the iOS app.

### 2. Configure iOS App

#### 2.1 Add New Files to Xcode Project

The cloud integration added two new Swift files that need to be added to your Xcode project:

1. Open `ContextBuilder.xcodeproj` in Xcode
2. Right-click on the `Shared` folder in the Project Navigator
3. Select "Add Files to 'ContextBuilder'..."
4. Navigate to and select:
   - `Shared/ContextUploadService.swift`
5. Ensure both targets are selected:
   - ✅ ContextBuilder
   - ✅ ContextBuilderShareExtension
6. Click "Add"

7. Right-click on the `ContextBuilder` folder
8. Select "Add Files to 'ContextBuilder'..."
9. Navigate to and select:
   - `ContextBuilder/SettingsView.swift`
10. Ensure only the main target is selected:
    - ✅ ContextBuilder
    - ❌ ContextBuilderShareExtension
11. Click "Add"

#### 2.2 Build the iOS App

1. In Xcode, select your target device/simulator
2. Press **Cmd+B** to build
3. Fix any build errors if they appear

#### 2.3 Run the App

1. Press **Cmd+R** to run
2. The app should launch successfully

### 3. Configure Cloud Sync

#### 3.1 Open Settings

1. In the app, tap the **gear icon** (⚙️) in the top-left corner
2. This opens the Settings screen

#### 3.2 Enter API Endpoint

1. In the "API Endpoint URL" field, paste the `ApiEndpoint` value from Step 1.5
2. Example: `https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev`
3. Tap "Done"

#### 3.3 Test Connection (Optional)

Tap the "Test Connection" button to verify the endpoint is working.

### 4. Upload Context to Cloud

#### 4.1 Save Some Context

Use the Share Sheet to save some content:
1. Open Safari and highlight some text
2. Tap "Share"
3. Select "Context Builder"
4. Wait for "Saved successfully!"

#### 4.2 Upload to Cloud

1. Open the Context Builder app
2. Tap the **•••** menu (ellipsis icon) in the top-right
3. Select "Upload to Cloud"
4. Confirm "Upload All"
5. Wait for upload to complete

#### 4.3 Verify Upload

You can verify the upload worked by checking:
- CloudWatch Logs in AWS Console
- DynamoDB table (`ContextItems-dev`)
- S3 bucket (`context-builder-attachments-dev-ACCOUNT_ID`)

Or test the API directly:

```bash
curl "https://your-api-endpoint/dev/list?userId=default&limit=10"
```

### 5. Set Up MCP Server (Optional)

The MCP server lets AI assistants like Claude access your saved context.

#### 5.1 Run MCP Server Locally

```bash
cd backend
npm run build
node dist/handlers/mcp.js
```

#### 5.2 Configure Claude Desktop

1. Open/create the config file:
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`

2. Add this configuration:

```json
{
  "mcpServers": {
    "context-builder": {
      "command": "node",
      "args": ["/absolute/path/to/context-builder-ios/backend/dist/handlers/mcp.js"]
    }
  }
}
```

3. Restart Claude Desktop

#### 5.3 Test MCP Server

In Claude Desktop, try:
- "Search my saved context for 'keyword'"
- "List my recent context items"
- "What context do I have saved?"

## Troubleshooting

### Backend Issues

**Build fails:**
```bash
cd backend
rm -rf node_modules dist
npm install
npm run build
```

**Deployment fails:**
- Check AWS credentials: `aws sts get-caller-identity`
- Ensure IAM permissions for CloudFormation, Lambda, DynamoDB, S3
- Check CloudFormation stack events in AWS Console

**Lambda errors:**
- Check CloudWatch Logs in AWS Console
- Look for the log group: `/aws/lambda/context-builder-upload-dev`

### iOS App Issues

**Build errors in Xcode:**
- Clean build folder: **Cmd+Shift+K**
- Rebuild: **Cmd+B**
- Ensure files were added to correct targets

**Upload fails:**
- Check API endpoint in Settings
- Verify endpoint is accessible: `curl https://your-endpoint/dev/list`
- Check CloudWatch Logs for Lambda errors

**Settings not persisting:**
- Delete and reinstall the app
- Check UserDefaults are working

### MCP Server Issues

**Server won't start:**
- Ensure you ran `npm run build` first
- Check Node.js version: `node --version` (should be 20.x+)
- Look for TypeScript errors in build output

**Claude Desktop doesn't see the server:**
- Verify config file path and JSON syntax
- Use absolute path in `args`
- Restart Claude Desktop completely
- Check Claude Desktop logs

## Cost Estimate

With AWS Free Tier (first 12 months), expected costs: **$0-1/month**

After Free Tier: **$1-5/month** for typical personal use

Cost breakdown:
- Lambda: $0.20 per 1M requests
- DynamoDB: $0.25 per GB-month (on-demand)
- S3: $0.023 per GB-month
- API Gateway: $1.00 per million requests
- Data transfer: $0.09 per GB

## Security Considerations

⚠️ **Important**: This demo app has NO authentication.

Anyone with your API endpoint URL can:
- Upload context items
- List all your saved context

### For Production Use:

1. **Add API Keys**: Use API Gateway API keys
2. **Add Authentication**: Implement AWS Cognito
3. **Add Rate Limiting**: Configure API Gateway throttling
4. **Add Encryption**: Enable DynamoDB encryption at rest
5. **Add WAF**: Use AWS WAF for API protection
6. **Use HTTPS Only**: Already configured

## Next Steps

### Enhancements to Consider

- **Automatic Sync**: Background upload when app enters foreground
- **Sync Status**: Show which items are synced vs. local-only
- **Conflict Resolution**: Handle same item edited on multiple devices
- **Selective Sync**: Choose which items to upload
- **Search**: Full-text search via DynamoDB or OpenSearch
- **Sharing**: Generate public links for specific context items
- **Web App**: Build a web interface to view your context
- **Multi-User**: Add user authentication and isolation

### Cleanup

To delete all AWS resources:

```bash
cd backend
sam delete
```

This removes:
- Lambda functions
- API Gateway
- DynamoDB table (and all data)
- S3 bucket (must be empty first)

## Additional Resources

- [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)
- [Model Context Protocol Docs](https://modelcontextprotocol.io/)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [iOS App Groups Guide](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)

## Support

For issues:
1. Check CloudWatch Logs for backend errors
2. Check Xcode console for iOS errors
3. Review this guide's Troubleshooting section
4. Open an issue on GitHub (if applicable)

---

**Happy context building!** 🚀
