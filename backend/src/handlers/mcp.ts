import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { DynamoDBService } from '../services/DynamoDBService';
import { S3Service } from '../services/S3Service';
import { ContextItem, ContextItemKind } from '../models/ContextItem';

const dynamoDBService = new DynamoDBService();
const s3Service = new S3Service();

/**
 * MCP Server for serving context to AI assistants
 */
class ContextMCPServer {
  private server: Server;

  constructor() {
    this.server = new Server(
      {
        name: 'context-builder',
        version: '1.0.0',
      },
      {
        capabilities: {
          resources: {},
          tools: {},
        },
      }
    );

    this.setupHandlers();
  }

  private setupHandlers() {
    // List available resources (context items)
    this.server.setRequestHandler(
      ListResourcesRequestSchema,
      async (request) => {
        const userId = 'default';
        const items = await dynamoDBService.listContextItemsByDate(userId, 100);

        return {
          resources: items.map((item) => ({
            uri: `context://${userId}/${item.id}`,
            name: this.getItemTitle(item),
            description: this.getItemDescription(item),
            mimeType: this.getItemMimeType(item),
          })),
        };
      }
    );

    // Read a specific resource
    this.server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
      const uri = request.params.uri;
      const match = uri.match(/^context:\/\/([^\/]+)\/([^\/]+)$/);

      if (!match) {
        throw new Error(`Invalid resource URI: ${uri}`);
      }

      const [, userId, itemId] = match;
      const item = await dynamoDBService.getContextItem(userId, itemId);

      if (!item) {
        throw new Error(`Context item not found: ${itemId}`);
      }

      // Build resource content
      let content = '';
      let mimeType = 'text/plain';

      switch (item.kind) {
        case ContextItemKind.TEXT:
          content = item.text || '';
          mimeType = 'text/plain';
          break;

        case ContextItemKind.URL:
          content = `URL: ${item.url}\n\nSaved from: ${item.sourceAppBundleID || 'Unknown'}`;
          mimeType = 'text/plain';
          break;

        case ContextItemKind.IMAGE:
        case ContextItemKind.FILE:
          if (item.attachmentS3Key) {
            const presignedUrl = await s3Service.getPresignedUrl(
              item.attachmentS3Key
            );
            content = `Attachment: ${item.originalFilename || 'Unnamed'}\nType: ${item.attachmentContentType || 'Unknown'}\nSize: ${item.attachmentSize || 0} bytes\nDownload URL: ${presignedUrl}\n\nNote: This URL is valid for 1 hour.`;
          } else {
            content = 'No attachment data available';
          }
          mimeType = 'text/plain';
          break;
      }

      return {
        contents: [
          {
            uri,
            mimeType,
            text: content,
          },
        ],
      };
    });

    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'search_context',
            description:
              'Search through saved context items by text content. Returns matching context items.',
            inputSchema: {
              type: 'object',
              properties: {
                query: {
                  type: 'string',
                  description: 'Search query text',
                },
                userId: {
                  type: 'string',
                  description: 'User ID (defaults to "default")',
                },
              },
              required: ['query'],
            },
          },
          {
            name: 'list_recent_context',
            description:
              'List the most recent context items saved by the user',
            inputSchema: {
              type: 'object',
              properties: {
                limit: {
                  type: 'number',
                  description: 'Maximum number of items to return (default: 10)',
                },
                userId: {
                  type: 'string',
                  description: 'User ID (defaults to "default")',
                },
              },
            },
          },
          {
            name: 'get_context_item',
            description: 'Get full details of a specific context item by ID',
            inputSchema: {
              type: 'object',
              properties: {
                itemId: {
                  type: 'string',
                  description: 'Context item ID (UUID)',
                },
                userId: {
                  type: 'string',
                  description: 'User ID (defaults to "default")',
                },
              },
              required: ['itemId'],
            },
          },
        ],
      };
    });

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      switch (name) {
        case 'search_context':
          return await this.handleSearchContext(args);

        case 'list_recent_context':
          return await this.handleListRecentContext(args);

        case 'get_context_item':
          return await this.handleGetContextItem(args);

        default:
          throw new Error(`Unknown tool: ${name}`);
      }
    });
  }

  private async handleSearchContext(args: any) {
    const query = args.query as string;
    const userId = (args.userId as string) || 'default';

    const items = await dynamoDBService.searchContextItems(userId, query);

    const results = items.map((item) => this.formatContextItem(item));

    return {
      content: [
        {
          type: 'text',
          text: `Found ${items.length} context items matching "${query}":\n\n${results.join('\n\n')}`,
        },
      ],
    };
  }

  private async handleListRecentContext(args: any) {
    const limit = (args.limit as number) || 10;
    const userId = (args.userId as string) || 'default';

    const items = await dynamoDBService.listContextItemsByDate(userId, limit);

    const results = items.map((item) => this.formatContextItem(item));

    return {
      content: [
        {
          type: 'text',
          text: `Recent context items (${items.length}):\n\n${results.join('\n\n')}`,
        },
      ],
    };
  }

  private async handleGetContextItem(args: any) {
    const itemId = args.itemId as string;
    const userId = (args.userId as string) || 'default';

    const item = await dynamoDBService.getContextItem(userId, itemId);

    if (!item) {
      return {
        content: [
          {
            type: 'text',
            text: `Context item not found: ${itemId}`,
          },
        ],
      };
    }

    return {
      content: [
        {
          type: 'text',
          text: this.formatContextItem(item, true),
        },
      ],
    };
  }

  private formatContextItem(item: ContextItem, detailed: boolean = false): string {
    const date = new Date(item.createdAt).toLocaleString();
    let result = `[${item.kind.toUpperCase()}] ${this.getItemTitle(item)}\n`;
    result += `Created: ${date}\n`;

    if (item.sourceAppBundleID) {
      result += `Source: ${item.sourceAppBundleID}\n`;
    }

    if (detailed || item.kind === ContextItemKind.TEXT) {
      if (item.text) {
        result += `\nContent:\n${item.text}\n`;
      }
    }

    if (item.kind === ContextItemKind.URL && item.url) {
      result += `URL: ${item.url}\n`;
    }

    if (
      (item.kind === ContextItemKind.IMAGE || item.kind === ContextItemKind.FILE) &&
      item.originalFilename
    ) {
      result += `Filename: ${item.originalFilename}\n`;
      result += `Type: ${item.attachmentContentType || 'Unknown'}\n`;
      if (item.attachmentSize) {
        result += `Size: ${(item.attachmentSize / 1024).toFixed(2)} KB\n`;
      }
    }

    return result;
  }

  private getItemTitle(item: ContextItem): string {
    switch (item.kind) {
      case ContextItemKind.TEXT:
        return item.text
          ? item.text.substring(0, 50) + (item.text.length > 50 ? '...' : '')
          : 'Empty text';

      case ContextItemKind.URL:
        return item.url || 'No URL';

      case ContextItemKind.IMAGE:
        return item.originalFilename || 'Image';

      case ContextItemKind.FILE:
        return item.originalFilename || 'File';

      default:
        return 'Unknown';
    }
  }

  private getItemDescription(item: ContextItem): string {
    const date = new Date(item.createdAt).toLocaleString();
    return `${item.kind} saved on ${date} from ${item.sourceAppBundleID || 'unknown app'}`;
  }

  private getItemMimeType(item: ContextItem): string {
    if (item.attachmentContentType) {
      return item.attachmentContentType;
    }

    switch (item.kind) {
      case ContextItemKind.TEXT:
      case ContextItemKind.URL:
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Context Builder MCP Server running on stdio');
  }
}

// Lambda handler that wraps the MCP server
export const handler = async (event: any) => {
  console.log('MCP Server handler invoked', { event });

  // For Lambda, we'll return information about how to connect to the MCP server
  // The actual MCP server needs to run as a stdio process, not directly in Lambda

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
    body: JSON.stringify({
      name: 'Context Builder MCP Server',
      version: '1.0.0',
      description:
        'MCP server for serving saved context to AI assistants. This server implements the Model Context Protocol and provides access to context items stored in DynamoDB.',
      capabilities: {
        resources: true,
        tools: true,
      },
      tools: [
        {
          name: 'search_context',
          description: 'Search through saved context items',
        },
        {
          name: 'list_recent_context',
          description: 'List recent context items',
        },
        {
          name: 'get_context_item',
          description: 'Get a specific context item by ID',
        },
      ],
      note: 'To use this MCP server with Claude Desktop or other MCP clients, you need to run it as a stdio process. Deploy the server code to your local machine and configure your MCP client to connect via stdio.',
    }),
  };
};

// For standalone stdio execution
if (require.main === module) {
  const server = new ContextMCPServer();
  server.run().catch(console.error);
}
