import { type CanActivate, type ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Request } from 'express';

export const ADMIN_HEADER = 'x-plan-admin-key';

@Injectable()
export class AdminKeyGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const expected = this.config.get<string>('PLAN_ADMIN_KEY');
    if (!expected) {
      throw new ForbiddenException('Panel de administración deshabilitado (PLAN_ADMIN_KEY no configurada)');
    }
    const request = context.switchToHttp().getRequest<Request>();
    const provided = request.headers[ADMIN_HEADER];
    if (provided !== expected) {
      throw new ForbiddenException('X-Plan-Admin-Key inválida');
    }
    return true;
  }
}
