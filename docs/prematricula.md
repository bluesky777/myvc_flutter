# Prematrícula de la familia

La tarjeta «Prematrícula 2027» sale en la portada (`MuroScreen`) del **acudiente**, encima de
las publicaciones. Las decisiones vienen de la web: myvc_front
`docs/pantallas/PANTALLAS-MATRICULA.md` §9.

```mermaid
flowchart LR
  M[GET ChangesAsked/to-me] -->|grados_sig, alumnos[].prematricula, falta_pago_renovacion| T[TarjetaDePrematricula]
  T -->|elige grupo y confirma| P[PUT matriculas/prematricular estado PREA]
  P -->|200 o 404| R[recarga el muro: sale el sello]
  P -->|409| F[«primero tesorería tiene que registrar el pago»]
```

- **El interruptor es del colegio, no de la app.** Con `years.prematr_antiguos` apagado, el
  servidor no manda `prematricula` ni `grados_sig`, y la tarjeta no sale.
- **El pago.** Si el colegio marcó «Sólo con el formulario pagado»
  (`prematr_antiguos_exige_pago`), al hijo sin la renovación pagada le llega
  `falta_pago_renovacion: true`. El renglón lo dice en vez de ofrecer el botón. Si aun así
  llega un 409, la app enseña la frase del servidor y cambia el renglón. El pago se hace en
  tesorería; la app no cobra.
- **El 404 es que quedó guardada.** `putPrematricular` relee con `anio_sig` y puede no
  encontrar la fila que acaba de escribir. Se recarga el muro y el sello lo confirma.
- Ya prematriculado, matriculado o asistente: un sello con el grupo y «Para cambiar el grupo,
  acércate a secretaría».

Código: `lib/Http/PrematriculaApi.dart`, `lib/Widgets/TarjetaDePrematricula.dart`. Pruebas:
`test/prematricula_test.dart`.
