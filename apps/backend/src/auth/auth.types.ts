export class AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export class JwtUser {
  id: string;
  email: string;
  name?: string | null;
  avatarUrl?: string | null;
  gravatarUrl?: string;
}

export class AuthResponse extends AuthTokens {
  user: JwtUser;
}

export interface JwtPayload {
  sub: string;
  email: string;
}
