// Genera assets/retos/reto.html: tools/retos/plantilla.html con el CSS y el motor de los retos
// de myvc_front (app2/src/app/comunes/act/retos/motor.ts y estilos-del-motor.ts) dentro.
//
//   node tools/retos/generar.mjs [ruta de myvc_front]      (por defecto ../myvc_front)
//
// Se corre cada vez que cambia el motor en el front, y se publica la app: el backend califica con
// su copia en PHP del mismo motor, así que un reto viejo en el celular puede calificar distinto.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const app = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const front = resolve(app, process.argv[2] ?? '../myvc_front');
const retos = join(front, 'app2/src/app/comunes/act/retos');

const motorTs = readFileSync(join(retos, 'motor.ts'), 'utf8');
const estilosTs = readFileSync(join(retos, 'estilos-del-motor.ts'), 'utf8');

// motor.ts es JS con una anotación de tipo y un `export` al final: se quitan las dos.
const cabecera = 'const motor: Record<string, any> = (() => {';
if (!motorTs.includes(cabecera)) throw new Error(`motor.ts ya no empieza con «${cabecera}»: revisar el generador`);
const motor = motorTs
  .replace(cabecera, 'const motor = (() => {')
  .replace(/^export const \{[^\n]*\n?/m, '')
  .replace(/^\/\/ @ts-nocheck\n/m, '')
  .replace(/^\/\* eslint-disable \*\/\n/m, '');
if (/^export /m.test(motor)) throw new Error('motor.ts tiene otro `export`: revisar el generador');

const literal = estilosTs.match(/^const CSS_DEL_MOTOR = ("(?:[^"\\]|\\.)*");/m);
if (!literal) throw new Error('No encuentro CSS_DEL_MOTOR en estilos-del-motor.ts');
const css = JSON.parse(literal[1]);

const sello = createHash('sha256').update(motor).update(css).digest('hex').slice(0, 12);
const pagina = readFileSync(join(app, 'tools/retos/plantilla.html'), 'utf8')
  .replace('<!doctype html>', `<!doctype html>\n<!-- GENERADO por tools/retos/generar.mjs; no se edita a mano. Motor ${sello}. -->`)
  .replace('/*CSS*/', () => css.replace(/<\/style/gi, '<\\/style'))
  .replace('/*MOTOR*/', () => motor.replace(/<\/script/gi, '<\\/script'));

const salida = join(app, 'assets/retos/reto.html');
mkdirSync(dirname(salida), { recursive: true });
writeFileSync(salida, pagina);
console.log(`assets/retos/reto.html: ${pagina.length} bytes, motor ${sello}`);
