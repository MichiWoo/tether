import { describe, expect, it } from 'vitest';
import { objectKey, sanitizeKeySegment } from './file.mapper.js';

describe('objectKey', () => {
  it('incluye el nombre sanitizado tras el fileId', () => {
    expect(objectKey('u1', 'f1', 'foto.jpg')).toBe('users/u1/f1/foto.jpg');
  });

  it('conserva el nombre con espacios y caracteres comunes', () => {
    expect(objectKey('u1', 'f1', 'Mi Archivo 2026.png')).toBe('users/u1/f1/Mi Archivo 2026.png');
  });

  it('cae al key base si el nombre es nulo o vacío', () => {
    expect(objectKey('u1', 'f1', null)).toBe('users/u1/f1');
    expect(objectKey('u1', 'f1')).toBe('users/u1/f1');
  });
});

describe('sanitizeKeySegment', () => {
  it('reemplaza separadores de ruta y caracteres de control', () => {
    expect(sanitizeKeySegment('a/b\\c\u0001d.txt')).toBe('a_b_c_d.txt');
  });

  it('trunca nombres muy largos y quita puntos finales', () => {
    const long = 'x'.repeat(300);
    const result = sanitizeKeySegment(`${long}.`);
    expect(result.length).toBeLessThanOrEqual(120);
    expect(result.endsWith('.')).toBe(false);
  });

  it('devuelve "file" si queda vacío tras sanitizar', () => {
    expect(sanitizeKeySegment('   ')).toBe('file');
  });

  it('convierte slashes en guiones bajos (no los elimina)', () => {
    expect(sanitizeKeySegment('///')).toBe('___');
  });
});
