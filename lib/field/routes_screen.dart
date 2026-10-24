import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'field_session.dart';

class RoutesScreen extends StatefulWidget {
  final FieldSession session;
  const RoutesScreen({super.key, required this.session});
  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final search = TextEditingController();
  final selected = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> people = [];
  Map<String, dynamic>? plan;
  MapLibreMapController? map;
  bool busy = false, styleReady = false;
  String? error;
  int page = 0, total = 0;
  static const size = 8;
  bool located(Map p) =>
      p['address']?['latitude'] != null && p['address']?['longitude'] != null;
  String address(Map p) => ['street', 'houseNumber', 'neighborhood', 'city']
      .map((k) => p['address']?[k])
      .where((v) => v != null && '$v'.isNotEmpty)
      .join(', ');
  double number(dynamic v) => v is num ? v.toDouble() : double.parse('$v');
  @override
  void initState() {
    super.initState();
    widget.session.addListener(sessionChanged);
    if (widget.session.isAdmin && !widget.session.locked) load();
  }

  void sessionChanged() {
    if (!mounted || (!widget.session.locked && widget.session.isAdmin)) return;
    setState(() {
      people = [];
      selected.clear();
      plan = null;
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(sessionChanged);
    search.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy || widget.session.locked || !widget.session.isAdmin) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is DioException
              ? (e.response?.data is Map
                        ? e.response?.data['message']?.toString()
                        : null) ??
                    'No se pudo conectar. Los recorridos requieren internet.'
              : 'No se pudo completar la operación. Intenta nuevamente.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => run(() async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'size': '$size',
        'search': search.text.trim(),
        'sort': 'fullName,asc',
      },
    ).query;
    final data = await widget.session.routeRequest('GET', '/api/people?$query');
    if (!mounted) return;
    setState(() {
      people = (data['items'] as List)
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
      total = data['total'] as int;
    });
    await paintMap();
  });
  Future<void> paintMap() async {
    final controller = map;
    if (!mounted || !styleReady || controller == null) return;
    final points = <LatLng>[];
    if (plan != null) {
      for (final s in plan!['stops']) {
        points.add(
          LatLng(number(s['coordinates'][1]), number(s['coordinates'][0])),
        );
      }
    } else {
      final rows = <int, Map>{
        for (final p in [...people, ...selected]) p['id'] as int: p,
      };
      for (final p in rows.values.where(located)) {
        points.add(
          LatLng(
            number(p['address']['latitude']),
            number(p['address']['longitude']),
          ),
        );
      }
    }
    await controller.clearCircles();
    await controller.clearLines();
    for (final p in points) {
      await controller.addCircle(
        CircleOptions(
          geometry: p,
          circleRadius: 8,
          circleColor: '#176b61',
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 3,
        ),
      );
    }
    if (plan != null) {
      final line = (plan!['geometry']['coordinates'] as List)
          .map((p) => LatLng(number(p[1]), number(p[0])))
          .toList();
      await controller.addLine(
        LineOptions(geometry: line, lineColor: '#176b61', lineWidth: 5),
      );
      points.addAll(line);
    }
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 16),
      );
    } else if (points.isNotEmpty) {
      final lat = points.map((p) => p.latitude),
          lng = points.map((p) => p.longitude);
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(lat.reduce(math.min), lng.reduce(math.min)),
            northeast: LatLng(lat.reduce(math.max), lng.reduce(math.max)),
          ),
          left: 35,
          right: 35,
          top: 35,
          bottom: 35,
        ),
      );
    }
  }

  void toggle(Map<String, dynamic> p) {
    if (busy) return;
    setState(() {
      plan = null;
      final index = selected.indexWhere((s) => s['id'] == p['id']);
      if (index >= 0) {
        selected.removeAt(index);
      } else if (selected.length < 25) {
        selected.add(p);
      } else {
        error = 'Selecciona como máximo 25 viviendas.';
      }
    });
    run(paintMap);
  }

  void move(int index, int delta) {
    if (busy) return;
    setState(() {
      final stop = selected.removeAt(index);
      selected.insert(index + delta, stop);
      plan = null;
    });
    run(paintMap);
  }

  Future<void> generate() => run(() async {
    final data = await widget.session.routeRequest(
      'POST',
      '/api/admin/routes/plan',
      data: {'personIds': selected.map((p) => p['id']).toList()},
    );
    if (!mounted) return;
    setState(() => plan = Map<String, dynamic>.from(data));
    await paintMap();
  });
  Future<void> locate(Map<String, dynamic> person) async {
    List<dynamic> candidates = [];
    await run(() async {
      candidates = List.from(
        await widget.session.routeRequest(
          'GET',
          '/api/admin/routes/people/${person['id']}/geocode',
        ),
      );
    });
    if (!mounted) return;
    final latitude = TextEditingController(
      text: person['address']?['latitude']?.toString() ?? '',
    );
    final longitude = TextEditingController(
      text: person['address']?['longitude']?.toString() ?? '',
    );
    final result = await showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ubicar: ${person['fullName']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(address(person)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Comprueba la dirección antes de confirmar. También puedes introducir coordenadas.',
                ),
              ),
              if (candidates.isEmpty)
                const Text('No hay coincidencias disponibles.'),
              for (final c in candidates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${c['label']}'),
                  subtitle: Text('${c['latitude']}, ${c['longitude']}'),
                  trailing: const Icon(Icons.check_circle_outline),
                  onTap: () => Navigator.pop(context, {
                    'latitude': number(c['latitude']),
                    'longitude': number(c['longitude']),
                  }),
                ),
              TextField(
                controller: latitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Latitud (-90 a 90)',
                ),
              ),
              TextField(
                controller: longitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Longitud (-180 a 180)',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final lat = double.tryParse(
                        latitude.text.replaceAll(',', '.'),
                      ),
                      lng = double.tryParse(
                        longitude.text.replaceAll(',', '.'),
                      );
                  if (lat == null ||
                      lng == null ||
                      !lat.isFinite ||
                      !lng.isFinite ||
                      lat.abs() > 90 ||
                      lng.abs() > 180) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Revisa la latitud y longitud.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, {'latitude': lat, 'longitude': lng});
                },
                child: const Text('Confirmar coordenadas'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
    // Controllers remain alive until the bottom sheet's closing animation ends.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    latitude.dispose();
    longitude.dispose();
    if (result == null || !mounted) return;
    await run(() async {
      await widget.session.routeRequest(
        'PUT',
        '/api/admin/routes/people/${person['id']}/location',
        data: result,
      );
      if (!mounted) return;
      setState(() {
        person['address'] = {
          ...Map<String, dynamic>.from(person['address']),
          ...result,
        };
        for (final p in selected.where((p) => p['id'] == person['id'])) {
          p['address'] = person['address'];
        }
        plan = null;
      });
      await paintMap();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.locked || !widget.session.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Acceso exclusivo para administradores.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa y recorridos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ubica viviendas y prepara tu jornada',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (busy) const LinearProgressIndicator(),
          SizedBox(
            height: 340,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MapLibreMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(4.6, -74.1),
                  zoom: 7,
                ),
                styleString:
                    'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
                onMapCreated: (controller) => map = controller,
                onStyleLoadedCallback: () {
                  styleReady = true;
                  run(paintMap);
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '© OpenStreetMap · © CARTO | Nominatim · OSRM',
              style: TextStyle(fontSize: 11),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    labelText: 'Nombre, documento o suscriptor',
                  ),
                  onSubmitted: (_) {
                    if (!busy) {
                      page = 0;
                      load();
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: busy
                    ? null
                    : () {
                        page = 0;
                        load();
                      },
                icon: const Icon(Icons.search),
                tooltip: 'Buscar viviendas',
              ),
            ],
          ),
          for (final p in people)
            Card(
              child: Column(
                children: [
                  CheckboxListTile(
                    value: selected.any((s) => s['id'] == p['id']),
                    onChanged: busy || !located(p) ? null : (_) => toggle(p),
                    title: Text('${p['fullName']}'),
                    subtitle: Text(address(p)),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: busy || p['address'] == null
                          ? null
                          : () => locate(p),
                      icon: const Icon(Icons.location_on_outlined),
                      label: Text(
                        located(p) ? 'Revisar ubicación' : 'Ubicar vivienda',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!busy && people.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No se encontraron viviendas.'),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: busy || page == 0
                    ? null
                    : () {
                        page--;
                        load();
                      },
                child: const Text('Anterior'),
              ),
              Text('${page + 1} / ${math.max(1, (total / size).ceil())}'),
              TextButton(
                onPressed: busy || (page + 1) * size >= total
                    ? null
                    : () {
                        page++;
                        load();
                      },
                child: const Text('Siguiente'),
              ),
            ],
          ),
          const Divider(),
          Text(
            'Recorrido · ${selected.length}/25 viviendas',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'La primera selección es el inicio y la última es el destino. Se ordenarán las paradas intermedias para un recorrido en vehículo.',
            ),
          ),
          for (var i = 0; i < selected.length; i++)
            ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text('${selected[i]['fullName']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: busy || i == 0 ? null : () => move(i, -1),
                    icon: const Icon(Icons.keyboard_arrow_up),
                    tooltip: 'Mover parada arriba',
                  ),
                  IconButton(
                    onPressed: busy || i == selected.length - 1
                        ? null
                        : () => move(i, 1),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    tooltip: 'Mover parada abajo',
                  ),
                  IconButton(
                    onPressed: busy ? null : () => toggle(selected[i]),
                    icon: const Icon(Icons.close),
                    tooltip: 'Retirar parada',
                  ),
                ],
              ),
            ),
          FilledButton.icon(
            onPressed: busy || selected.length < 2 ? null : generate,
            icon: const Icon(Icons.route),
            label: const Text('Generar recorrido'),
          ),
          if (plan != null) ...[
            const SizedBox(height: 20),
            Text(
              '${(number(plan!['distance']) / 1000).toStringAsFixed(1)} km · ${(number(plan!['duration']) / 60).ceil()} min estimados',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Tiempo de conducción, sin visitas ni tráfico en tiempo real.',
            ),
            for (final s in plan!['stops'])
              ListTile(
                leading: CircleAvatar(
                  child: Text('${(s['order'] as num).toInt() + 1}'),
                ),
                title: Text('${s['name']}'),
                subtitle: Text('${s['address']}'),
              ),
          ],
        ],
      ),
    );
  }
}
