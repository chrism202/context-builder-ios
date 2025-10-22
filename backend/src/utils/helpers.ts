/**
 * Utility functions for Context Builder backend
 */

/**
 * Get file extension from MIME type
 */
export function getExtensionFromMimeType(mimeType: string): string {
  const mimeToExt: Record<string, string> = {
    'image/png': 'png',
    'image/jpeg': 'jpg',
    'image/jpg': 'jpg',
    'image/heic': 'heic',
    'image/heif': 'heif',
    'image/gif': 'gif',
    'image/webp': 'webp',
    'application/pdf': 'pdf',
    'text/plain': 'txt',
    'application/json': 'json',
    'application/zip': 'zip',
    'application/x-zip-compressed': 'zip',
    'video/mp4': 'mp4',
    'video/quicktime': 'mov',
    'audio/mpeg': 'mp3',
    'audio/mp4': 'm4a',
  };

  return mimeToExt[mimeType.toLowerCase()] || 'dat';
}

/**
 * Extract file extension from filename
 */
export function getFileExtension(filename: string): string {
  const parts = filename.split('.');
  if (parts.length > 1) {
    return parts[parts.length - 1].toLowerCase();
  }
  return 'dat';
}

/**
 * Validate context item data
 */
export function validateContextItem(item: any): {
  valid: boolean;
  error?: string;
} {
  if (!item.kind) {
    return { valid: false, error: 'Missing required field: kind' };
  }

  const validKinds = ['text', 'url', 'image', 'file'];
  if (!validKinds.includes(item.kind)) {
    return { valid: false, error: `Invalid kind: ${item.kind}` };
  }

  // Validate content based on kind
  if (item.kind === 'text' && !item.text) {
    return { valid: false, error: 'Text items must have text field' };
  }

  if (item.kind === 'url' && !item.url) {
    return { valid: false, error: 'URL items must have url field' };
  }

  if (
    (item.kind === 'image' || item.kind === 'file') &&
    !item.attachmentData
  ) {
    return {
      valid: false,
      error: 'Image and file items must have attachmentData field',
    };
  }

  return { valid: true };
}

/**
 * Format date to ISO 8601 string
 */
export function formatDate(date: Date = new Date()): string {
  return date.toISOString();
}

/**
 * Parse API Gateway event body
 */
export function parseBody<T>(body: string | null): T | null {
  if (!body) {
    return null;
  }

  try {
    return JSON.parse(body) as T;
  } catch (error) {
    console.error('Error parsing body:', error);
    return null;
  }
}

/**
 * Create API response
 */
export function createResponse(
  statusCode: number,
  body: any,
  headers: Record<string, string> = {}
) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Allow-Methods': '*',
      ...headers,
    },
    body: JSON.stringify(body),
  };
}
