import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  PutCommand,
  QueryCommand,
  GetCommand,
  ScanCommand,
} from '@aws-sdk/lib-dynamodb';
import { ContextItem } from '../models/ContextItem';

export class DynamoDBService {
  private docClient: DynamoDBDocumentClient;
  private tableName: string;

  constructor() {
    const client = new DynamoDBClient({});
    this.docClient = DynamoDBDocumentClient.from(client);
    this.tableName = process.env.CONTEXT_TABLE_NAME || 'ContextItems-dev';
  }

  /**
   * Save a context item to DynamoDB
   */
  async saveContextItem(item: ContextItem): Promise<void> {
    const command = new PutCommand({
      TableName: this.tableName,
      Item: item,
    });

    await this.docClient.send(command);
  }

  /**
   * Get a specific context item
   */
  async getContextItem(userId: string, id: string): Promise<ContextItem | null> {
    const command = new GetCommand({
      TableName: this.tableName,
      Key: {
        userId,
        id,
      },
    });

    const result = await this.docClient.send(command);
    return result.Item as ContextItem | null;
  }

  /**
   * List all context items for a user
   */
  async listContextItems(
    userId: string,
    limit?: number
  ): Promise<ContextItem[]> {
    const command = new QueryCommand({
      TableName: this.tableName,
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId,
      },
      Limit: limit,
      ScanIndexForward: false, // Most recent first
    });

    const result = await this.docClient.send(command);
    return (result.Items as ContextItem[]) || [];
  }

  /**
   * List context items ordered by creation date
   */
  async listContextItemsByDate(
    userId: string,
    limit?: number
  ): Promise<ContextItem[]> {
    const command = new QueryCommand({
      TableName: this.tableName,
      IndexName: 'CreatedAtIndex',
      KeyConditionExpression: 'userId = :userId',
      ExpressionAttributeValues: {
        ':userId': userId,
      },
      Limit: limit,
      ScanIndexForward: false, // Most recent first
    });

    const result = await this.docClient.send(command);
    return (result.Items as ContextItem[]) || [];
  }

  /**
   * Search context items by text content
   */
  async searchContextItems(
    userId: string,
    searchText: string
  ): Promise<ContextItem[]> {
    const allItems = await this.listContextItems(userId);

    // Simple text search - filter items containing the search text
    return allItems.filter((item) => {
      const searchLower = searchText.toLowerCase();
      if (item.text && item.text.toLowerCase().includes(searchLower)) {
        return true;
      }
      if (item.url && item.url.toLowerCase().includes(searchLower)) {
        return true;
      }
      if (
        item.originalFilename &&
        item.originalFilename.toLowerCase().includes(searchLower)
      ) {
        return true;
      }
      return false;
    });
  }
}
