export const EVENTS = {
  deviceOnline: 'device.online',
  deviceOffline: 'device.offline',
  clipboardUpdated: 'clipboard.updated',
  fileReady: 'file.ready',
  shareCreated: 'share.created',
  shareAccepted: 'share.accepted',
  shareDownloaded: 'share.downloaded',
  shareExpired: 'share.expired',
} as const;

export type RealtimeEvent = (typeof EVENTS)[keyof typeof EVENTS];
