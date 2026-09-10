import {
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import type { QuotaErrorCode } from '@tether/protocol';

export class QuotaExceededException extends HttpException {
  readonly code: QuotaErrorCode;

  constructor(code: QuotaErrorCode, message: string, extra: Record<string, unknown> = {}) {
    const status =
      code === 'QUOTA_FILE_TOO_LARGE' || code === 'QUOTA_STORAGE_EXCEEDED'
        ? HttpStatus.PAYLOAD_TOO_LARGE
        : HttpStatus.CONFLICT;
    super(
      {
        statusCode: status,
        code,
        message,
        ...extra,
      },
      status,
    );
    this.code = code;
  }
}
