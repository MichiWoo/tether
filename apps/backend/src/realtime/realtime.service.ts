import { Injectable } from '@nestjs/common';
import { Server } from 'socket.io';
import type { RealtimeEvent } from './realtime-events.js';

@Injectable()
export class RealtimeService {
  private server: Server | null = null;

  setServer(server: Server): void {
    this.server = server;
  }

  emitToUser(userId: string, event: RealtimeEvent, payload: unknown): void {
    this.server?.to(`user:${userId}`).emit(event, payload);
  }

  emitToDevice(deviceId: string, event: RealtimeEvent, payload: unknown): void {
    this.server?.to(`device:${deviceId}`).emit(event, payload);
  }
}
