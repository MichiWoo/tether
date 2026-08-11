import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getRoot(): { name: string; status: string } {
    return { name: 'tether-api', status: 'running' };
  }
}
