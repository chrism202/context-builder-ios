import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { DynamoDBService } from '../services/DynamoDBService';
import { S3Service } from '../services/S3Service';
import { ListResponse } from '../models/ContextItem';
import { createResponse } from '../utils/helpers';

const dynamoDBService = new DynamoDBService();
const s3Service = new S3Service();

/**
 * Lambda handler for listing context items
 */
export const handler = async (
  event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyResultV2> => {
  console.log('List handler invoked', { event });

  try {
    const userId =
      event.queryStringParameters?.userId || 'default';
    const limit = event.queryStringParameters?.limit
      ? parseInt(event.queryStringParameters.limit, 10)
      : undefined;
    const includeUrls = event.queryStringParameters?.includeUrls === 'true';

    // Get context items from DynamoDB
    const items = await dynamoDBService.listContextItemsByDate(userId, limit);

    // Optionally include presigned URLs for attachments
    if (includeUrls) {
      for (const item of items) {
        if (item.attachmentS3Key) {
          try {
            const presignedUrl = await s3Service.getPresignedUrl(
              item.attachmentS3Key,
              3600 // 1 hour
            );
            // Add presigned URL as a temporary field
            (item as any).attachmentUrl = presignedUrl;
          } catch (error) {
            console.error('Error generating presigned URL:', error);
          }
        }
      }
    }

    const response: ListResponse = {
      items,
      count: items.length,
    };

    return createResponse(200, response);
  } catch (error) {
    console.error('List handler error:', error);
    return createResponse(500, {
      error: 'Internal server error',
      message: error instanceof Error ? error.message : String(error),
    });
  }
};
