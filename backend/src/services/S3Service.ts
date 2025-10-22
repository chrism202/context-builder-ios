import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

export class S3Service {
  private client: S3Client;
  private bucketName: string;

  constructor() {
    this.client = new S3Client({});
    this.bucketName =
      process.env.ATTACHMENTS_BUCKET_NAME || 'context-builder-attachments';
  }

  /**
   * Upload an attachment to S3
   * @param key S3 object key (e.g., "userId/itemId.png")
   * @param data File data buffer or base64 string
   * @param contentType MIME type
   * @returns S3 object key
   */
  async uploadAttachment(
    key: string,
    data: Buffer | string,
    contentType: string
  ): Promise<string> {
    let bodyData: Buffer;

    if (typeof data === 'string') {
      // Assume base64 encoded string
      bodyData = Buffer.from(data, 'base64');
    } else {
      bodyData = data;
    }

    const command = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: key,
      Body: bodyData,
      ContentType: contentType,
    });

    await this.client.send(command);
    return key;
  }

  /**
   * Get a presigned URL for downloading an attachment
   * @param key S3 object key
   * @param expiresIn Expiration time in seconds (default: 1 hour)
   * @returns Presigned URL
   */
  async getPresignedUrl(key: string, expiresIn: number = 3600): Promise<string> {
    const command = new GetObjectCommand({
      Bucket: this.bucketName,
      Key: key,
    });

    return await getSignedUrl(this.client, command, { expiresIn });
  }

  /**
   * Get attachment metadata
   */
  async getAttachmentMetadata(key: string): Promise<{
    contentType?: string;
    size?: number;
  }> {
    const command = new HeadObjectCommand({
      Bucket: this.bucketName,
      Key: key,
    });

    try {
      const response = await this.client.send(command);
      return {
        contentType: response.ContentType,
        size: response.ContentLength,
      };
    } catch (error) {
      console.error('Error getting attachment metadata:', error);
      return {};
    }
  }

  /**
   * Generate S3 key for an attachment
   * Format: userId/itemId/filename or userId/itemId.extension
   */
  generateAttachmentKey(
    userId: string,
    itemId: string,
    filename?: string,
    extension?: string
  ): string {
    if (filename) {
      return `${userId}/${itemId}/${filename}`;
    }
    if (extension) {
      return `${userId}/${itemId}.${extension}`;
    }
    return `${userId}/${itemId}`;
  }
}
