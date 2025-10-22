import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { v4 as uuidv4 } from 'uuid';
import { DynamoDBService } from '../services/DynamoDBService';
import { S3Service } from '../services/S3Service';
import {
  ContextItem,
  ContextItemInput,
  UploadRequest,
  UploadResponse,
} from '../models/ContextItem';
import {
  parseBody,
  createResponse,
  validateContextItem,
  formatDate,
  getExtensionFromMimeType,
  getFileExtension,
} from '../utils/helpers';

const dynamoDBService = new DynamoDBService();
const s3Service = new S3Service();

/**
 * Lambda handler for uploading context items
 */
export const handler = async (
  event: APIGatewayProxyEventV2
): Promise<APIGatewayProxyResultV2> => {
  console.log('Upload handler invoked', { event });

  try {
    // Parse request body
    const request = parseBody<UploadRequest>(event.body || '');
    if (!request || !request.items || !Array.isArray(request.items)) {
      return createResponse(400, {
        success: false,
        error: 'Invalid request: items array required',
      });
    }

    const userId = request.userId || 'default';
    const itemIds: string[] = [];
    const errors: string[] = [];

    // Process each context item
    for (const itemInput of request.items) {
      try {
        // Validate item
        const validation = validateContextItem(itemInput);
        if (!validation.valid) {
          errors.push(`Validation error: ${validation.error}`);
          continue;
        }

        // Generate unique ID
        const itemId = uuidv4();
        const createdAt = formatDate();

        // Build context item
        const contextItem: ContextItem = {
          userId,
          id: itemId,
          createdAt,
          kind: itemInput.kind,
          sourceAppBundleID: itemInput.sourceAppBundleID,
        };

        // Handle content based on kind
        if (itemInput.text) {
          contextItem.text = itemInput.text;
        }

        if (itemInput.url) {
          contextItem.url = itemInput.url;
        }

        // Handle attachments (images and files)
        if (itemInput.attachmentData && itemInput.attachmentContentType) {
          const extension = itemInput.originalFilename
            ? getFileExtension(itemInput.originalFilename)
            : getExtensionFromMimeType(itemInput.attachmentContentType);

          const s3Key = s3Service.generateAttachmentKey(
            userId,
            itemId,
            undefined,
            extension
          );

          // Upload to S3
          await s3Service.uploadAttachment(
            s3Key,
            itemInput.attachmentData,
            itemInput.attachmentContentType
          );

          contextItem.attachmentS3Key = s3Key;
          contextItem.attachmentContentType = itemInput.attachmentContentType;
          contextItem.originalFilename = itemInput.originalFilename;

          // Calculate size from base64
          const base64Length = itemInput.attachmentData.length;
          const padding = (itemInput.attachmentData.match(/=/g) || []).length;
          contextItem.attachmentSize = Math.floor(
            (base64Length * 3) / 4 - padding
          );
        }

        // Save to DynamoDB
        await dynamoDBService.saveContextItem(contextItem);
        itemIds.push(itemId);

        console.log('Context item saved successfully', {
          itemId,
          kind: contextItem.kind,
        });
      } catch (error) {
        console.error('Error processing context item:', error);
        errors.push(`Error processing item: ${error}`);
      }
    }

    // Build response
    const response: UploadResponse = {
      success: itemIds.length > 0,
      itemIds,
    };

    if (errors.length > 0) {
      response.errors = errors;
    }

    const statusCode = response.success ? 200 : 400;
    return createResponse(statusCode, response);
  } catch (error) {
    console.error('Upload handler error:', error);
    return createResponse(500, {
      success: false,
      error: 'Internal server error',
      message: error instanceof Error ? error.message : String(error),
    });
  }
};
