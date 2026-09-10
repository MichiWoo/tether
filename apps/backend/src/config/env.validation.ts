import Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'qa', 'production', 'test').default('development'),
  PORT: Joi.number().port().default(3100),
  DATABASE_URL: Joi.string()
    .uri({ scheme: ['postgresql', 'postgres'] })
    .required(),
  REDIS_HOST: Joi.string().default('localhost'),
  REDIS_PORT: Joi.number().port().default(6379),
  SHARE_TTL_DAYS: Joi.number().integer().min(1).default(7),
  MINIO_ENDPOINT: Joi.string().required(),
  MINIO_PORT: Joi.number().port().default(9002),
  MINIO_USE_SSL: Joi.boolean().default(false),
  MINIO_PUBLIC_ENDPOINT: Joi.string()
    .uri({ scheme: ['http', 'https'] })
    .optional(),
  MINIO_ACCESS_KEY: Joi.string().required(),
  MINIO_SECRET_KEY: Joi.string().required(),
  MINIO_BUCKET: Joi.string().required(),
  MINIO_RELEASES_BUCKET: Joi.string().default('releases'),
  RELEASES_API_KEY: Joi.string().allow('').optional(),
  JWT_SECRET: Joi.string().min(32).required(),
  JWT_EXPIRES_IN: Joi.string().default('15m'),
  REFRESH_TOKEN_SECRET: Joi.string().min(32).required(),
  REFRESH_TOKEN_EXPIRES_IN: Joi.string().default('30d'),
  CORS_ORIGINS: Joi.string().allow('').optional(),
  PLAN_ADMIN_KEY: Joi.string().allow('').optional(),
});

export const envValidationOptions: Joi.ValidationOptions = {
  abortEarly: false,
  allowUnknown: true,
};
