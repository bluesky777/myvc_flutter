import 'package:flutter/material.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:myvc_flutter/Http/Server.dart';
import 'package:myvc_flutter/Menu/MenuLateral.dart';
import 'package:myvc_flutter/Models/GrupoModel.dart';
import 'package:myvc_flutter/Widgets/TituloPantalla.dart';
import 'package:myvc_flutter/Utils/Analitica.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PanelScreen extends StatefulWidget {
  const PanelScreen({super.key});

  @override
  _PanelScreen createState() => _PanelScreen();
}

class _PanelScreen extends State<PanelScreen> {
  Server server = Server();
  List<GrupoModel>? grupos;
  String? error;
  final _drawerController = ZoomDrawerController();

  @override
  void initState() {
    super.initState();
    _traerGrupos();
  }

  /// Los grupos del docente.
  ///
  /// Con await y try/catch de verdad. Antes el try envolvía la *creación* del
  /// Future, no su resultado: un servidor caído, una dirección mal escrita o un
  /// token vencido fallaban después de que el try hubiera terminado, nadie
  /// recogía el error y la pantalla se quedaba en «Esperando grupos...» para
  /// siempre. Es la primera pantalla después de entrar, así que era justo
  /// donde más se notaba.
  Future<void> _traerGrupos() async {
    setState(() {
      error = null;
      grupos = null;
    });

    try {
      final response = await server.get('/grupos');
      if (!mounted) return;

      if (response.statusCode >= 300) {
        setState(() => error = 'El servidor respondió ${response.statusCode}.');
        return;
      }

      final traidos = grupoModelFromJson(response.body);
      setState(() => grupos = traidos);
    } catch (err) {
      if (!mounted) return;
      setState(() => error = '$err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZoomDrawer(
      menuScreen: MenuLateral(),
      controller: _drawerController,
      borderRadius: 40.0,
      slideWidth: 300,
      showShadow: true,
      angle: -8.0,
      style: DrawerStyle.style1,
      // Sin esto el menú no se podía cerrar: mainScreenAbsorbPointer viene en
      // true, así que con el menú abierto la pantalla principal se traga los
      // toques y el icono ☰ deja de responder; y mainScreenTapClose viene en
      // false, así que tocar fuera tampoco cerraba. Solo quedaba arrastrar.
      mainScreenTapClose: true,
      androidCloseOnBackTap: true,
      mainScreen: Scaffold(
        appBar: AppBar(
          // «Asistencias», como la llama el menú, y debajo qué toca hacer
          // aquí. Antes ponía solo «Elija grupo», que dice el paso pero no de
          // qué: se llega desde el menú y no hay nada más que lo diga.
          title: TituloPantalla(
            titulo: 'Asistencias',
            subtitulo: 'Elige el grupo',
          ),
          leading: GestureDetector(
            child: Icon(Icons.menu),
            onTap: () {
              _drawerController.toggle!();
            },
          ),
        ),
        body: _buildCuerpo(),
      ),
    );
  }

  Widget _buildCuerpo() {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No se pudieron traer los grupos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _traerGrupos,
                child: Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (grupos == null) {
      return Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: Analitica.refresco('panel', _traerGrupos),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: _buildListaGrupos(),
      ),
    );
  }

  Widget _buildListaGrupos() => ListView.builder(
        scrollDirection: Axis.vertical,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: grupos!.length,
        itemBuilder: (context, index) {
          GrupoModel grupo = grupos![index];
          return ListTile(
            title: Text(grupo.nombre),
            leading: CircleAvatar(
              child: Text(grupo.abrev),
            ),
            onTap: () async {
              final preferences = await SharedPreferences.getInstance();
              await preferences.setString('grupoSelected', grupo.toRawJson());
              // El context aquí es el del itemBuilder, no el del State: hay
              // que preguntarle a él si sigue montado.
              if (!context.mounted) return;
              Navigator.pushNamed(context, '/alum-tardanza-cole');
            },
            trailing: Icon(Icons.arrow_right),
          );
        },
      );

  Widget buildTile(GrupoModel grupo) => ListTile(
        title: Text(
          grupo.nombre,
          //style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
}
