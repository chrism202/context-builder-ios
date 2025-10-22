/**
 * Context Item data model
 * Matches the iOS ContextItem struct for compatibility
 */

export enum ContextItemKind {
  TEXT = 'text',
  URL = 'url',
  IMAGE = 'image',
  FILE = 'file',
}

export interface ContextItem {
  // Partition key: userId for multi-user support (default: 'default')
  userId: string;

  // Sort key: unique identifier
  id: string;

  // Timestamp
  createdAt: string; // ISO 8601 format

  // Content type
  kind: ContextItemKind;

  // Source metadata
  sourceAppBundleID?: string;

  // Content fields (based on kind)
  text?: string;
  url?: string;

  // Attachment metadata (for images and files)
  attachmentS3Key?: string; // S3 object key
  attachmentContentType?: string; // MIME type
  originalFilename?: string;
  attachmentSize?: number; // Size in bytes
}

export interface ContextItemInput {
  kind: ContextItemKind;
  sourceAppBundleID?: string;
  text?: string;
  url?: string;
  attachmentData?: string; // Base64 encoded
  attachmentContentType?: string;
  originalFilename?: string;
}

export interface UploadRequest {
  items: ContextItemInput[];
  userId?: string; // Optional, defaults to 'default'
}

export interface UploadResponse {
  success: boolean;
  itemIds: string[];
  errors?: string[];
}

export interface ListResponse {
  items: ContextItem[];
  count: number;
}
