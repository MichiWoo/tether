import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';
import { RefreshTokenDto } from './dto/refresh-token.dto.js';
import { UpdateProfileDto } from './dto/update-profile.dto.js';
import { UpdatePasswordDto } from './dto/update-password.dto.js';
import { JwtAuthGuard } from './guards/jwt-auth.guard.js';
import { CurrentUser } from './decorators/current-user.decorator.js';
import { AuthResponse, AuthTokens, JwtUser } from './auth.types.js';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiOperation({
    summary: 'Registrar usuario',
    description: 'Crea una cuenta y devuelve access + refresh tokens',
  })
  @ApiResponse({ status: 201, description: 'Usuario creado y tokens emitidos', type: AuthResponse })
  @ApiResponse({ status: 409, description: 'El email ya está registrado' })
  register(@Body() dto: RegisterDto): Promise<AuthResponse> {
    return this.authService.register(dto);
  }

  @Post('login')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiOperation({ summary: 'Iniciar sesión', description: 'Valida credenciales y emite tokens' })
  @ApiResponse({ status: 201, description: 'Login exitoso con tokens', type: AuthResponse })
  @ApiResponse({ status: 401, description: 'Credenciales inválidas' })
  login(@Body() dto: LoginDto): Promise<AuthResponse> {
    return this.authService.login(dto);
  }

  @Post('refresh')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiOperation({
    summary: 'Rotar refresh token',
    description: 'Revoca el refresh token actual y emite un par nuevo',
  })
  @ApiResponse({ status: 201, description: 'Nuevo par de tokens', type: AuthTokens })
  @ApiResponse({ status: 401, description: 'Refresh token inválido, expirado o ya usado' })
  refresh(@Body() dto: RefreshTokenDto): Promise<AuthTokens> {
    return this.authService.refresh(dto.refreshToken);
  }

  @Post('logout')
  @ApiOperation({ summary: 'Cerrar sesión', description: 'Revoca el refresh token indicado' })
  @ApiResponse({ status: 201, description: 'Refresh token revocado' })
  async logout(@Body() dto: RefreshTokenDto): Promise<{ success: true }> {
    await this.authService.logout(dto.refreshToken);
    return { success: true };
  }

  @Get('me')
  @ApiBearerAuth('access-token')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Perfil del usuario autenticado' })
  @ApiResponse({ status: 200, description: 'Datos públicos del usuario', type: JwtUser })
  @ApiResponse({ status: 401, description: 'No autenticado' })
  me(@CurrentUser() user: JwtUser): Promise<JwtUser> {
    return this.authService.getMe(user.id);
  }

  @Patch('profile')
  @ApiBearerAuth('access-token')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({
    summary: 'Actualizar perfil',
    description: 'Actualiza nombre y avatarUrl (vacío = usar Gravatar)',
  })
  @ApiResponse({ status: 200, description: 'Perfil actualizado', type: JwtUser })
  @ApiResponse({ status: 401, description: 'No autenticado' })
  updateProfile(@CurrentUser() user: JwtUser, @Body() dto: UpdateProfileDto): Promise<JwtUser> {
    return this.authService.updateProfile(user.id, dto);
  }

  @Patch('password')
  @ApiBearerAuth('access-token')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Cambiar contraseña', description: 'Requiere la contraseña actual' })
  @ApiResponse({ status: 200, description: 'Contraseña actualizada' })
  @ApiResponse({ status: 401, description: 'Contraseña actual incorrecta' })
  updatePassword(
    @CurrentUser() user: JwtUser,
    @Body() dto: UpdatePasswordDto,
  ): Promise<{ success: true }> {
    return this.authService.updatePassword(user.id, dto);
  }
}
