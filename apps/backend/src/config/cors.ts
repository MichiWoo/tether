export function allowedOrigins(): string[] {
  const raw = process.env.CORS_ORIGINS?.trim();
  if (!raw) {
    return ['*'];
  }
  return raw
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
}

export function isOriginAllowed(origin: string | undefined): boolean {
  if (!origin) {
    return true;
  }
  const allowed = allowedOrigins();
  if (allowed.includes('*')) {
    return true;
  }
  return allowed.includes(origin);
}
