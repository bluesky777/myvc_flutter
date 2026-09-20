import 'package:flutter/material.dart';
import 'package:myvc_flutter/Controllers/LoginController.dart';
import 'package:myvc_flutter/Http/AuthService.dart';
import 'package:myvc_flutter/Utils/ContextoAcademico.dart';
import 'package:myvc_flutter/Utils/Interruptores.dart';

/// El menú lateral, uno solo para toda la app.
///
/// Antes había dos: el del inicio, con la cabecera y el cierre de sesión, y
/// otro distinto en el listado de alumnos con un único elemento que no llevaba
/// a ninguna parte. Ahora las dos pantallas montan este mismo.
class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      // El SafeArea va por dentro y no envolviéndolo todo: la cabecera tiene
      // que llegar hasta el borde de arriba, por debajo de la barra de estado.
      // Envolviendo la Column entera, el fondo arrancaba más abajo y quedaba
      // una franja del color del Scaffold encima.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCabecera(context),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ..._opciones(context),
                  Divider(height: 20, thickness: 2, indent: 20, endIndent: 20),
                  ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Cerrar sesión'),
                    onTap: () async {
                      await LoginController().logout();

                      if (!context.mounted) return;

                      Navigator.pushNamedAndRemoveUntil(
                          context, '/login', (ruta) => false);
                    },
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lo que ve cada quien.
  ///
  /// El muro es de todos; lo demás depende del rol. Un alumno no tiene nada que
  /// hacer en el listado de grupos del colegio, y un docente no tiene «Mis
  /// notas» que mirar.
  List<Widget> _opciones(BuildContext context) {
    final usuario = AuthService.user;

    final opciones = <Widget>[
      // «Inicio» y no «Publicaciones»: es la primera opción y la pantalla a la
      // que vuelve todo el mundo, y lo que se dice en un menú es a dónde
      // lleva, no qué hay dentro. El muro sigue siendo el muro por debajo, y
      // la ruta sigue llamándose /muro.
      _opcion(
        context,
        icono: Icons.home_outlined,
        texto: 'Inicio',
        ruta: '/muro',
      ),
    ];

    if (usuario.esAlumno || usuario.esAcudiente) {
      opciones.addAll([
        _opcion(
          context,
          icono: Icons.school_outlined,
          texto: 'Mis notas',
          ruta: '/mis-notas',
        ),
        _opcion(
          context,
          icono: Icons.event_available_outlined,
          texto: 'Asistencia',
          ruta: '/mi-asistencia',
        ),
        // La misma palabra que ve el personal, y otra ruta detrás: aquélla es
        // la de editar y lleva `auth.personal`, que aquí contestaría 403.
        // Sigue detrás del interruptor porque la condición es el despliegue y
        // no el código — hoy cumplida en los quince desde el 25 ago 2026.
        if (Interruptores.disciplinaMisFichas)
          _opcion(
            context,
            icono: Icons.gavel_outlined,
            texto: 'Disciplina',
            ruta: '/mi-disciplina',
          ),
        _opcionPrivacidad(context),
      ]);
      return opciones;
    }

    // Docentes, administrativos y superusuarios.
    opciones.add(_opcion(
      context,
      icono: Icons.fact_check_outlined,
      texto: 'Asistencias',
      ruta: '/panel',
    ));

    // Notas antes que Unidades porque es lo que se hace a diario: las unidades
    // se montan al empezar el periodo y las notas se pasan todas las semanas.
    opciones.add(_opcion(
      context,
      icono: Icons.edit_note_outlined,
      texto: 'Notas',
      ruta: '/notas',
    ));

    // Debajo de Notas porque es la misma tarea vista al revés: allí se ponen
    // y aquí se repasa lo que quedó por debajo de la mínima. No es diaria
    // —se mira al acercarse el cierre— pero se llega desde el mismo sitio.
    opciones.add(_opcion(
      context,
      icono: Icons.trending_down,
      texto: 'Notas perdidas',
      ruta: '/notas-perdidas',
    ));

    opciones.add(_opcion(
      context,
      icono: Icons.menu_book_outlined,
      texto: 'Unidades',
      ruta: '/unidades',
    ));

    // Debajo de Unidades porque es la otra mitad de «con qué evalúo»: allí los
    // porcentajes y aquí el texto que sale en el boletín.
    //
    // **Dos puertas y no una, y las dos hacen falta.** El interruptor espera al
    // despliegue —de las siete rutas de `desempenos/` y de las dos columnas de
    // `listasignaturas`—; `vaPorCompetencias` es del colegio, y sin él la opción
    // llevaría a una pantalla que a ese colegio no le sirve de nada. Enseñar una
    // pantalla que no se usa nunca es peor que no tenerla: se abre una vez, no
    // se entiende, y la próxima vez que haga falta ya nadie se fía.
    //
    // El rótulo es la palabra del colegio —«Competencias» o «Desempeños»—,
    // nunca una de la app. Ver `ConfiguracionColegio.competencias`.
    if (Interruptores.competenciasDocente &&
        ContextoAcademico.instancia.config.vaPorCompetencias) {
      opciones.add(_opcion(
        context,
        icono: Icons.checklist_outlined,
        texto: ContextoAcademico.instancia.config.competencias,
        ruta: '/mis-competencias',
      ));
    }

    // «Disciplina» y no «Convivencia» ni «Observador»: es como se llama la
    // pantalla equivalente en la plataforma web y como la nombra el colegio al
    // pedirla. Los alumnos y los acudientes ven una opción con este mismo
    // nombre, pero es la suya —`/mi-disciplina`, en sólo lectura—: **ésta** no
    // la ven, porque las rutas que escriben llevan `auth.personal` y les
    // responderían 403. La única de disciplina que no lo lleva es
    // `mis-fichas`.
    opciones.add(_opcion(
      context,
      icono: Icons.gavel_outlined,
      texto: 'Disciplina',
      ruta: '/disciplina',
    ));

    // Solo para quien administra cuentas —superusuario, Admin o Secretario—, y
    // aquí sí se esconde de verdad en vez de enseñarla en gris como
    // Configuración. La diferencia es qué se ve dentro: Configuración le
    // explica a un docente por qué hoy no puede editar notas, y esto es el
    // listado con el nombre de usuario y el celular de las familias de un
    // grupo. Un docente no tiene nada que mirar ahí.
    if (usuario.administraCuentas) {
      opciones.add(_opcion(
        context,
        icono: Icons.manage_accounts_outlined,
        texto: 'Usuarios',
        ruta: '/usuarios',
      ));
    }

    // **El día de matrículas, y para todo el personal**: quien atiende una
    // estación es un docente de pie en un aula, no un administrador. Es la
    // contrapartida de que cerrar un paso lo pueda hacer cualquiera del
    // personal —decidido el 20 sep 2026—, así que esconderla por rol aquí
    // contradiría la pantalla.
    //
    // **Apagada no sale, en vez de salir vacía.** `docs/estaciones.md` §2.8: un
    // colegio que no armó su recorrido y un módulo que todavía no existe se
    // leen igual, y no son lo mismo. Mientras el interruptor esté apagado no
    // hay ninguna de las dos cosas que enseñar.
    //
    // **Y cuando se encienda harán falta dos puertas, no una**, como en
    // «Mis competencias»: ésta espera al despliegue de las ocho rutas, y la
    // segunda —si este colegio configuró estaciones— solo se sabe preguntando
    // a `GET estaciones`, que hoy no existe.
    if (Interruptores.estaciones) {
      opciones.add(_opcion(
        context,
        icono: Icons.how_to_reg_outlined,
        texto: 'Estaciones',
        ruta: '/estaciones',
      ));
    }

    // **Buscar a cualquiera y ver en qué va su matrícula.** Va detrás del
    // recorrido y no de las estaciones, y la diferencia importa: buscar
    // funciona hoy —`buscar/por-nombre` lleva desplegada desde mucho antes—
    // pero encontrar a alguien para chocar contra una pantalla apagada no
    // sirve de nada. Lo que hace útil esta entrada es poder abrir el recorrido.
    //
    // **Y por eso puede salir meses antes que «Estaciones»**: su ruta no es de
    // las ocho, es la que Joseth entregó el 20 sep. Esto contesta «¿y mi hija
    // en qué va?» un lunes en secretaría, sin nada del día de matrículas
    // montado.
    if (Interruptores.recorridoDeMatricula) {
      opciones.add(_opcion(
        context,
        icono: Icons.person_search_outlined,
        texto: 'Buscar',
        ruta: '/buscar-matriculas',
      ));
    }

    // La última, y para todo el personal aunque casi todo lo que hay dentro
    // solo lo pueda mover un administrador: la mitad de su gracia es explicarle
    // a un docente por qué hoy no puede editar notas, o qué significa un 85.
    opciones.add(_opcion(
      context,
      icono: Icons.settings_outlined,
      texto: 'Configuración',
      ruta: '/configuracion',
    ));

    opciones.add(_opcionPrivacidad(context));

    return opciones;
  }

  /// La última para todo el mundo, y **para todo el mundo de verdad**.
  ///
  /// Va aparte en vez de al lado de «Configuración» porque esa es del colegio y
  /// solo la ve el personal, y esto lo tiene que poder apagar quien sea dueño
  /// del teléfono: un acudiente igual que un coordinador. Es la única opción
  /// que aparece en las dos ramas de este menú, y por eso se escribe una vez.
  Widget _opcionPrivacidad(BuildContext context) {
    return _opcion(
      context,
      icono: Icons.privacy_tip_outlined,
      texto: 'Privacidad',
      ruta: '/privacidad',
    );
  }

  Widget _opcion(
    BuildContext context, {
    required IconData icono,
    required String texto,
    required String ruta,
  }) {
    return ListTile(
      leading: Icon(icono),
      title: Text(texto),
      onTap: () =>
          Navigator.pushNamedAndRemoveUntil(context, ruta, (_) => false),
    );
  }

  /// La cabecera del menú: el logo de fondo y el usuario encima.
  ///
  /// Así era antes de que el commit 3ff68a4 unificara los dos menús: al
  /// extraer este, la cabecera se rehízo como una columna con la imagen de 70
  /// px arriba y el nombre debajo, o sea que el logo dejó de ser un fondo y
  /// pasó a ser una fila más del menú.
  ///
  /// El velo oscuro de abajo no es adorno: el logo tiene zonas claras y sin él
  /// el nombre en blanco se pierde justo encima de ellas.
  Widget _buildCabecera(BuildContext context) {
    final alturaBarra = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 180 + alturaBarra,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/logoMy.png', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quien queda firmando cada tardanza. nombreVisible y no
                // `nombres ?? 'Sin identificar'`: los usuarios de tipo Usuario
                // no tienen ficha con nombres, y para ellos el nombre de
                // usuario ES el nombre. Decirles «Sin identificar» a quienes sí
                // están identificados no tenía sentido.
                Text(
                  AuthService.user.nombreVisible,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  AuthService.user.username,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
