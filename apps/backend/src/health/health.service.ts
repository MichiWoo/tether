import { Injectable } from '@nestjs/common';

export interface HealthStatus {
  status: 'ok' | 'error';
  name: string;
  version: string;
  uptime: number;
  timestamp: string;
}

@Injectable()
export class HealthService {
  getStatus(): HealthStatus {
    return {
      status: 'ok',
      name: 'tether-api',
      version: process.env.npm_package_version ?? '0.1.0',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    };
  }
}
