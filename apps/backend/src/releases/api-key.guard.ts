import { Injectable, UnauthorizedException } from '@nestjs/common';
import type { CanActivate, ExecutionContext } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Request } from 'express';

@Injectable()
export class ApiKeyGuard implements CanActivate {
  constructor(private readonly configService: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const expected = this.configService.get<string>('RELEASES_API_KEY');
    if (!expected) {
      throw new UnauthorizedException('RELEASES_API_KEY no configurada');
    }
    const request = context.switchToHttp().getRequest<Request>();
    const provided = request.header('x-api-key');
    if (!provided || provided !== expected) {
      throw new UnauthorizedException('API key inválida');
    }
    return true;
  }
}
