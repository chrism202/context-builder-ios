# Context Builder Cloud Backend

AWS serverless backend for Context Builder iOS app with MCP (Model Context Protocol) server support.

## Architecture

- **API Gateway**: HTTP API for iOS app uploads
- **Lambda Functions**:
  - `upload`: Handles context item uploads from iOS app
  - `list`: Lists all context items for a user
  - `mcp`: MCP server for serving context to AI assistants
- **DynamoDB**: Stores context item metadata
- **S3**: Stores binary attachments (images, files)

## Prerequisites

- AWS Account
- AWS CLI configured with credentials
- AWS SAM CLI installed
- Node.js 20.x or later
- npm or yarn

## Installation

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Build the Project

```bash
npm run build
```

This compiles TypeScript to JavaScript in the `dist/` directory.

## Deployment

### First-Time Deployment

1. **Build the project**:
   ```bash
   npm run build
   ```

2. **Deploy using SAM**:
   ```bash
   sam deploy --guided
   ```

3. **Follow the prompts**:
   - Stack Name: `context-builder-stack` (or your choice)
   - AWS Region: Your preferred region (e.g., `us-east-1`)
   - Parameter Stage: `dev` or `prod`
   - Confirm changes before deploy: `Y`
   - Allow SAM CLI IAM role creation: `Y`
   - Save arguments to configuration file: `Y`

4. **Note the outputs**:
   After deployment, SAM will output:
   - `ApiEndpoint`: Your HTTP API URL (use this in iOS app settings)
   - `McpServerUrl`: MCP server function URL
   - `ContextTableName`: DynamoDB table name
   - `AttachmentsBucketName`: S3 bucket name

### Subsequent Deployments

After the first deployment, you can use:

```bash
npm run deploy:fast
```

This uses the saved configuration from `samconfig.toml`.

## Local Testing

### Run API Gateway Locally

```bash
npm run local:upload
```

This starts a local API Gateway on `http://127.0.0.1:3000`.

### Test Upload Endpoint

```bash
curl -X POST http://127.0.0.1:3000/upload \
  -H "Content-Type: application/json" \
  -d '{
    "items": [
      {
        "kind": "text",
        "text": "Test context item",
        "sourceAppBundleID": "com.test.app"
      }
    ],
    "userId": "default"
  }'
```

## Configuration

### Environment Variables

The Lambda functions use these environment variables (set automatically by CloudFormation):

- `STAGE`: Deployment stage (dev/prod)
- `CONTEXT_TABLE_NAME`: DynamoDB table name
- `ATTACHMENTS_BUCKET_NAME`: S3 bucket name

## API Endpoints

### Upload Context Items

**POST** `/upload`

Upload one or more context items.

Request body:
```json
{
  "items": [
    {
      "kind": "text",
      "text": "Sample text",
      "sourceAppBundleID": "com.apple.Safari"
    },
    {
      "kind": "image",
      "attachmentData": "base64-encoded-image-data",
      "attachmentContentType": "image/png",
      "originalFilename": "photo.png"
    }
  ],
  "userId": "default"
}
```

Response:
```json
{
  "success": true,
  "itemIds": ["uuid-1", "uuid-2"],
  "errors": []
}
```

### List Context Items

**GET** `/list?userId=default&limit=10&includeUrls=true`

Query parameters:
- `userId`: User ID (default: "default")
- `limit`: Maximum items to return (optional)
- `includeUrls`: Include presigned URLs for attachments (optional)

Response:
```json
{
  "items": [
    {
      "userId": "default",
      "id": "uuid",
      "createdAt": "2025-01-15T10:30:00.000Z",
      "kind": "text",
      "text": "Sample text",
      "sourceAppBundleID": "com.apple.Safari"
    }
  ],
  "count": 1
}
```

## MCP Server

The MCP server allows AI assistants to access your saved context.

### Running MCP Server Locally

For local development with Claude Desktop or other MCP clients:

```bash
cd backend
npm run build
node dist/handlers/mcp.js
```

### MCP Server Configuration

Add to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS):

```json
{
  "mcpServers": {
    "context-builder": {
      "command": "node",
      "args": ["/path/to/context-builder-ios/backend/dist/handlers/mcp.js"]
    }
  }
}
```

### MCP Tools

The server provides these tools:

1. **search_context**: Search through saved context items
   - Input: `query` (string), `userId` (optional)

2. **list_recent_context**: List recent context items
   - Input: `limit` (number), `userId` (optional)

3. **get_context_item**: Get a specific context item
   - Input: `itemId` (string), `userId` (optional)

### MCP Resources

Context items are exposed as resources with URIs like:
```
context://default/uuid-of-item
```

## Project Structure

```
backend/
├── src/
│   ├── handlers/          # Lambda function handlers
│   │   ├── upload.ts      # Upload handler
│   │   ├── list.ts        # List handler
│   │   └── mcp.ts         # MCP server handler
│   ├── services/          # Business logic
│   │   ├── DynamoDBService.ts
│   │   └── S3Service.ts
│   ├── models/            # Data models
│   │   └── ContextItem.ts
│   └── utils/             # Utility functions
│       └── helpers.ts
├── template.yaml          # SAM/CloudFormation template
├── package.json
├── tsconfig.json
└── README.md
```

## Development

### Watch Mode

For development with auto-compilation:

```bash
npm run watch
```

### Clean Build

```bash
npm run clean
npm run build
```

## Costs

With AWS Free Tier:
- **Lambda**: 1M free requests/month, 400,000 GB-seconds compute
- **DynamoDB**: 25 GB storage, 25 read/write units
- **S3**: 5 GB storage, 20,000 GET requests, 2,000 PUT requests
- **API Gateway**: 1M API calls/month (first 12 months)

Expected costs for personal use: **$0-5/month**

## Security Notes

⚠️ **This is a demo app without authentication.**

For production use, you should:
1. Add API key authentication to API Gateway
2. Implement user authentication (Cognito, etc.)
3. Add request validation and rate limiting
4. Enable CloudWatch alarms for monitoring
5. Use AWS WAF for API protection

## Troubleshooting

### Build Errors

If you get TypeScript errors:
```bash
npm install
npm run clean
npm run build
```

### Deployment Errors

If SAM deploy fails:
1. Check AWS credentials: `aws sts get-caller-identity`
2. Ensure you have IAM permissions for CloudFormation, Lambda, DynamoDB, S3, and API Gateway
3. Check CloudFormation events in AWS Console

### MCP Server Not Working

1. Ensure you built the project: `npm run build`
2. Check the path in your MCP client config
3. Look for errors in the MCP client logs

## Support

For issues or questions:
1. Check CloudWatch Logs for Lambda function errors
2. Review DynamoDB and S3 in AWS Console
3. Test endpoints with curl or Postman

## License

MIT
