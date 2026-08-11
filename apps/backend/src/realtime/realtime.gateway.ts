import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { OnGatewayConnection, OnGatewayDisconnect, OnGatewayInit } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import type { JwtPayload } from '../auth/auth.types.js';
import { isOriginAllowed } from '../config/cors.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { EVENTS } from './realtime-events.js';
import { RealtimeService } from './realtime.service.js';

@WebSocketGateway({
  cors: {
    origin: (origin: string, callback: (err: Error | null, allow?: boolean) => void) =>
      callback(null, isOriginAllowed(origin)),
    credentials: true,
  },
  path: '/realtime',
  transports: ['websocket', 'polling'],
})
export class RealtimeGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
    private readonly realtimeService: RealtimeService,
  ) {}

  afterInit(server: Server): void {
    this.realtimeService.setServer(server);
  }

  async handleConnection(client: Socket): Promise<void> {
    try {
      const token = client.handshake.auth?.token;
      if (typeof token !== 'string') {
        throw new Error('missing token');
      }
      const payload = await this.jwtService.verifyAsync<JwtPayload>(token, {
        secret: this.configService.get<string>('JWT_SECRET', 'change-me'),
      });
      const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user) {
        throw new Error('unknown user');
      }
      client.data.userId = user.id;
      client.data.deviceIds = new Set<string>();
      await client.join(`user:${user.id}`);
    } catch {
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket): void {
    const userId: string | undefined = client.data.userId;
    const deviceIds: Set<string> | undefined = client.data.deviceIds;
    if (!userId) {
      return;
    }
    for (const deviceId of deviceIds ?? []) {
      this.realtimeService.emitToUser(userId, EVENTS.deviceOffline, { deviceId });
    }
  }

  @SubscribeMessage('device:identify')
  async identify(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { deviceId?: unknown },
  ): Promise<void> {
    const userId: string | undefined = client.data.userId;
    if (!userId || typeof payload?.deviceId !== 'string' || payload.deviceId.length === 0) {
      return;
    }
    const device = await this.prisma.device.findFirst({
      where: { id: payload.deviceId, userId },
    });
    if (!device) {
      return;
    }
    await client.join(`device:${device.id}`);
    client.data.deviceIds?.add(device.id);
    await this.prisma.device.update({
      where: { id: device.id },
      data: { lastSeenAt: new Date() },
    });
    this.realtimeService.emitToUser(userId, EVENTS.deviceOnline, { deviceId: device.id });
  }
}
