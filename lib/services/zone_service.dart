import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────
// STATUT D'UNE ZONE
// ─────────────────────────────────────────────────────────

enum ZoneStatus {
  active,      // Troupeau ici maintenant
  attente,     // Pas encore utilisée
  repos,       // En récupération après utilisation
  prete,       // Récupérée — disponible
  finDeCycle,  // Bientôt à quitter
  epuisee,     // Critique — ne pas utiliser
}

extension ZoneStatusExt on ZoneStatus {
  String get label {
    switch (this) {
      case ZoneStatus.active:     return 'ACTIVE';
      case ZoneStatus.attente:    return 'EN ATTENTE';
      case ZoneStatus.repos:      return 'REPOS';
      case ZoneStatus.prete:      return 'PRÊTE';
      case ZoneStatus.finDeCycle: return 'FIN CYCLE';
      case ZoneStatus.epuisee:    return 'ÉPUISÉE';
    }
  }

  String get emoji {
    switch (this) {
      case ZoneStatus.active:     return '🟢';
      case ZoneStatus.attente:    return '⚪';
      case ZoneStatus.repos:      return '🔵';
      case ZoneStatus.prete:      return '🟡';
      case ZoneStatus.finDeCycle: return '🟠';
      case ZoneStatus.epuisee:    return '🔴';
    }
  }

  Color get couleur {
    switch (this) {
      case ZoneStatus.active:     return NexaTheme.vert;
      case ZoneStatus.attente:    return NexaTheme.gris;
      case ZoneStatus.repos:      return const Color(0xFF3B82F6);
      case ZoneStatus.prete:      return NexaTheme.or;
      case ZoneStatus.finDeCycle: return const Color(0xFFF97316);
      case ZoneStatus.epuisee:    return NexaTheme.rouge;
    }
  }

  String get description {
    switch (this) {
      case ZoneStatus.active:     return 'Zone en cours de pâturage';
      case ZoneStatus.attente:    return 'Pas encore analysée';
      case ZoneStatus.repos:      return 'En régénération — ne pas pâturer';
      case ZoneStatus.prete:      return 'Disponible pour la prochaine rotation';
      case ZoneStatus.finDeCycle: return 'Préparez le déplacement maintenant';
      case ZoneStatus.epuisee:    return 'Quittez immédiatement cette zone';
    }
  }

  String get actionLabel {
    switch (this) {
      case ZoneStatus.active:     return 'Pâturage en cours';
      case ZoneStatus.attente:    return 'Analyser cette zone';
      case ZoneStatus.repos:      return 'Repos — ne pas utiliser';
      case ZoneStatus.prete:      return 'Disponible maintenant';
      case ZoneStatus.finDeCycle: return 'Déplacer le troupeau bientôt';
      case ZoneStatus.epuisee:    return 'Partir immédiatement';
    }
  }
}

// ─────────────────────────────────────────────────────────
// MODÈLE ZONE TERRAIN
// ─────────────────────────────────────────────────────────

class TerrainZone {
  final String id;
  final String nom;
  final List<LatLng> polygon;
  final double surfaceHa;
  ZoneStatus status;
  AnalysisResult? derniereAnalyse;
  int joursDepuisDerniereAnalyse;
  int joursDisponibles;
  bool isNext;
  DateTime? dateDebutPaturage; // Quand le troupeau est arrivé ici

  TerrainZone({
    required this.id,
    required this.nom,
    required this.polygon,
    required this.surfaceHa,
    required this.status,
    this.derniereAnalyse,
    this.joursDepuisDerniereAnalyse = 0,
    this.joursDisponibles = 0,
    this.isNext = false,
    this.dateDebutPaturage,
  });

  LatLng get centre {
    if (polygon.isEmpty) return const LatLng(0, 0);
    double lat = 0, lng = 0;
    for (final p in polygon) { lat += p.latitude; lng += p.longitude; }
    return LatLng(lat / polygon.length, lng / polygon.length);
  }

  Color get couleur => status.couleur;
  String get emoji  => status.emoji;

  // Jours restants calculés depuis la date de début
  int get joursRestaants {
    if (dateDebutPaturage == null || joursDisponibles <= 0) return joursDisponibles;
    final passes = DateTime.now().difference(dateDebutPaturage!).inDays;
    return (joursDisponibles - passes).clamp(0, joursDisponibles);
  }

  // Copie avec nouveaux champs
  TerrainZone copyWith({
    ZoneStatus? status,
    AnalysisResult? derniereAnalyse,
    int? joursDisponibles,
    bool? isNext,
    DateTime? dateDebutPaturage,
  }) {
    return TerrainZone(
      id: id, nom: nom, polygon: polygon, surfaceHa: surfaceHa,
      status: status ?? this.status,
      derniereAnalyse: derniereAnalyse ?? this.derniereAnalyse,
      joursDepuisDerniereAnalyse: joursDepuisDerniereAnalyse,
      joursDisponibles: joursDisponibles ?? this.joursDisponibles,
      isNext: isNext ?? this.isNext,
      dateDebutPaturage: dateDebutPaturage ?? this.dateDebutPaturage,
    );
  }
}

// ─────────────────────────────────────────────────────────
// SERVICE PRINCIPAL
// ─────────────────────────────────────────────────────────

class ZoneService {

  // ── CLÉ HIVE ─────────────────────────────────────────────
  static const _kZones = 'terrain_zones_state';

  // ── DIVISION DU TERRAIN EN 4 ZONES ───────────────────────
  // Utilise Sutherland-Hodgman pour clipper le vrai polygone

  static List<TerrainZone> diviserTerrain({
    required List<LatLng> polygonTotal,
    required double surfaceHaTotal,
    String? zoneActiveId, // Zone choisie par l'éleveur
  }) {
    if (polygonTotal.length < 3) return [];

    final centre = _centroide(polygonTotal);
    final midLat = centre.latitude;
    final midLng = centre.longitude;
    final bbox   = _bbox(polygonTotal);
    final surfaceParZone = surfaceHaTotal / 4;

    final polyA = _clipPolygon(polygonTotal, latMin: midLat, latMax: bbox['maxLat']!, lngMin: bbox['minLng']!, lngMax: midLng);
    final polyB = _clipPolygon(polygonTotal, latMin: midLat, latMax: bbox['maxLat']!, lngMin: midLng, lngMax: bbox['maxLng']!);
    final polyC = _clipPolygon(polygonTotal, latMin: bbox['minLat']!, latMax: midLat, lngMin: midLng, lngMax: bbox['maxLng']!);
    final polyD = _clipPolygon(polygonTotal, latMin: bbox['minLat']!, latMax: midLat, lngMin: bbox['minLng']!, lngMax: midLng);

    final ids = ['A', 'B', 'C', 'D'];
    final polys = [
      polyA.isNotEmpty ? polyA : _quadrantFallback(polygonTotal, 'A', midLat, midLng, bbox),
      polyB.isNotEmpty ? polyB : _quadrantFallback(polygonTotal, 'B', midLat, midLng, bbox),
      polyC.isNotEmpty ? polyC : _quadrantFallback(polygonTotal, 'C', midLat, midLng, bbox),
      polyD.isNotEmpty ? polyD : _quadrantFallback(polygonTotal, 'D', midLat, midLng, bbox),
    ];

    return List.generate(4, (i) {
      final id = ids[i];
      final isActive = zoneActiveId == id;
      return TerrainZone(
        id: id,
        nom: 'Zone $id',
        polygon: polys[i],
        surfaceHa: surfaceParZone,
        // ✅ Fix Bug 2 — toutes ATTENTE sauf la zone choisie qui est ACTIVE
        status: zoneActiveId != null
            ? (isActive ? ZoneStatus.active : ZoneStatus.attente)
            : ZoneStatus.attente,
        isNext: false,
        dateDebutPaturage: isActive ? DateTime.now() : null,
      );
    });
  }

  // ── TRANSITION VERS LA ZONE SUIVANTE ─────────────────────

  static List<TerrainZone> effectuerTransition(
    List<TerrainZone> zones,
    String fromId,
    String toId,
  ) {
    return zones.map((z) {
      if (z.id == fromId) {
        // ✅ Fix Bug 4 — Zone quittée → REPOS
        // Jours de régénération = joursDisponibles utilisés * 0.75 (minimum 21 jours)
        final joursRegen = z.joursDisponibles > 0
            ? (z.joursDisponibles * 0.75).ceil().clamp(21, 90)
            : 30;
        return z.copyWith(
          status: ZoneStatus.repos,
          isNext: false,
          joursDisponibles: joursRegen, // ← jours de repos nécessaires
        );
      } else if (z.id == toId) {
        // ✅ Fix Bug 5 — Zone rejointe → ATTENTE_ANALYSE
        // L'éleveur DOIT analyser cette zone avant de voir les jours dispo
        return z.copyWith(
          status: ZoneStatus.active,
          isNext: false,
          joursDisponibles: 0, // ← 0 = pas encore analysée
          dateDebutPaturage: DateTime.now(),
        );
      }
      return z.copyWith(isNext: false);
    }).toList();
  }

  // ── METTRE À JOUR LE STATUT D'UNE ZONE APRÈS ANALYSE ─────
  // Quand une analyse est faite sur une zone, on met à jour son statut

  static List<TerrainZone> mettreAJourApresAnalyse(
    List<TerrainZone> zones,
    String zoneId,
    AnalysisResult result,
  ) {
    return zones.map((z) {
      if (z.id != zoneId) return z;

      ZoneStatus newStatus;
      switch (result.statut) {
        case PastureStatus.excellent:
        case PastureStatus.bon:
          newStatus = ZoneStatus.active;
          break;
        case PastureStatus.attention:
          newStatus = ZoneStatus.finDeCycle;
          break;
        case PastureStatus.critique:
          newStatus = ZoneStatus.epuisee;
          break;
      }

      return z.copyWith(
        status: newStatus,
        derniereAnalyse: result,
        joursDisponibles: result.joursDisponibles,
        dateDebutPaturage: DateTime.now(),
      );
    }).toList();
  }

  // ── CALCULER LA PROCHAINE ZONE ────────────────────────────

  static TerrainZone? prochaineZone(List<TerrainZone> zones, String activeId) {
    // Ordre de rotation : A→B→C→D→A
    final ordre = ['A', 'B', 'C', 'D'];
    final activeIndex = ordre.indexOf(activeId);
    if (activeIndex == -1) return null;

    for (int i = 1; i <= 4; i++) {
      final nextId = ordre[(activeIndex + i) % 4];
      final zone = zones.firstWhere((z) => z.id == nextId, orElse: () => zones.first);
      if (zone.status != ZoneStatus.active && zone.status != ZoneStatus.epuisee) {
        return zone;
      }
    }
    return null;
  }

  // ── PERSISTANCE HIVE ──────────────────────────────────────

  static Future<void> sauvegarderZones(List<TerrainZone> zones) async {
    final box = Hive.box('settings');
    final data = zones.map((z) => {
      'id': z.id,
      'status': z.status.index,
      'joursDisponibles': z.joursDisponibles,
      'isNext': z.isNext,
      'dateDebutPaturage': z.dateDebutPaturage?.toIso8601String(),
      'polygonLats': z.polygon.map((p) => p.latitude).toList(),
      'polygonLngs': z.polygon.map((p) => p.longitude).toList(),
      'surfaceHa': z.surfaceHa,
    }).toList();
    await box.put(_kZones, data);
  }

  static List<TerrainZone>? chargerZones() {
    final box = Hive.box('settings');
    final raw = box.get(_kZones);
    if (raw == null) return null;

    try {
      final list = (raw as List).cast<Map>();
      return list.map((m) {
        final lats = (m['polygonLats'] as List).cast<double>();
        final lngs = (m['polygonLngs'] as List).cast<double>();
        final polygon = List.generate(lats.length, (i) => LatLng(lats[i], lngs[i]));
        final id = m['id'] as String;
        return TerrainZone(
          id: id,
          nom: 'Zone $id',
          polygon: polygon,
          surfaceHa: (m['surfaceHa'] as num).toDouble(),
          status: ZoneStatus.values[m['status'] as int],
          joursDisponibles: m['joursDisponibles'] as int,
          isNext: m['isNext'] as bool,
          dateDebutPaturage: m['dateDebutPaturage'] != null
              ? DateTime.tryParse(m['dateDebutPaturage'] as String)
              : null,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> effacerZones() async {
    final box = Hive.box('settings');
    await box.delete(_kZones);
  }

  // ── RÉSUMÉ ────────────────────────────────────────────────

  static String resumeZones(List<TerrainZone> zones) {
    final active   = zones.where((z) => z.status == ZoneStatus.active).length;
    final repos    = zones.where((z) => z.status == ZoneStatus.repos).length;
    final pretes   = zones.where((z) => z.status == ZoneStatus.prete || z.status == ZoneStatus.attente).length;
    final epuisees = zones.where((z) => z.status == ZoneStatus.epuisee).length;
    return '$active active · $repos repos · $pretes dispo · $epuisees épuisées';
  }

  // ── ALGORITHME SUTHERLAND-HODGMAN ─────────────────────────

  static List<LatLng> _clipPolygon(
    List<LatLng> polygon, {
    required double latMin, required double latMax,
    required double lngMin, required double lngMax,
  }) {
    List<LatLng> out = List.from(polygon);

    out = _clipEdge(out, (p) => p.latitude >= latMin, (a, b) {
      final t = (latMin - a.latitude) / (b.latitude - a.latitude);
      return LatLng(latMin, a.longitude + t * (b.longitude - a.longitude));
    });
    out = _clipEdge(out, (p) => p.latitude <= latMax, (a, b) {
      final t = (latMax - a.latitude) / (b.latitude - a.latitude);
      return LatLng(latMax, a.longitude + t * (b.longitude - a.longitude));
    });
    out = _clipEdge(out, (p) => p.longitude >= lngMin, (a, b) {
      final t = (lngMin - a.longitude) / (b.longitude - a.longitude);
      return LatLng(a.latitude + t * (b.latitude - a.latitude), lngMin);
    });
    out = _clipEdge(out, (p) => p.longitude <= lngMax, (a, b) {
      final t = (lngMax - a.longitude) / (b.longitude - a.longitude);
      return LatLng(a.latitude + t * (b.latitude - a.latitude), lngMax);
    });
    return out;
  }

  static List<LatLng> _clipEdge(
    List<LatLng> poly,
    bool Function(LatLng) inside,
    LatLng Function(LatLng, LatLng) intersect,
  ) {
    if (poly.isEmpty) return [];
    final out = <LatLng>[];
    for (int i = 0; i < poly.length; i++) {
      final cur  = poly[i];
      final prev = poly[(i - 1 + poly.length) % poly.length];
      if (inside(cur)) {
        if (!inside(prev)) out.add(intersect(prev, cur));
        out.add(cur);
      } else if (inside(prev)) {
        out.add(intersect(prev, cur));
      }
    }
    return out;
  }

  static List<LatLng> _quadrantFallback(
    List<LatLng> polygon, String id, double midLat, double midLng,
    Map<String, double> bbox,
  ) {
    switch (id) {
      case 'A': return [LatLng(bbox['maxLat']!, bbox['minLng']!), LatLng(bbox['maxLat']!, midLng), LatLng(midLat, midLng), LatLng(midLat, bbox['minLng']!)];
      case 'B': return [LatLng(bbox['maxLat']!, midLng), LatLng(bbox['maxLat']!, bbox['maxLng']!), LatLng(midLat, bbox['maxLng']!), LatLng(midLat, midLng)];
      case 'C': return [LatLng(midLat, midLng), LatLng(midLat, bbox['maxLng']!), LatLng(bbox['minLat']!, bbox['maxLng']!), LatLng(bbox['minLat']!, midLng)];
      default:  return [LatLng(midLat, bbox['minLng']!), LatLng(midLat, midLng), LatLng(bbox['minLat']!, midLng), LatLng(bbox['minLat']!, bbox['minLng']!)];
    }
  }

  static LatLng _centroide(List<LatLng> points) {
    double lat = 0, lng = 0;
    for (final p in points) { lat += p.latitude; lng += p.longitude; }
    return LatLng(lat / points.length, lng / points.length);
  }

  static Map<String, double> _bbox(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat)  minLat = p.latitude;
      if (p.latitude > maxLat)  maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return {'minLat': minLat, 'maxLat': maxLat, 'minLng': minLng, 'maxLng': maxLng};
  }
}

// ─────────────────────────────────────────────────────────
// ARGS NAVIGATION CARTE
// Défini ici pour éviter les imports circulaires
// ─────────────────────────────────────────────────────────

class MapScreenArgs {
  final List<TerrainZone>? zones;
  final List<LatLng>? polygonPoints;
  final double? surfaceHa;
  final String? highlightZoneId;

  const MapScreenArgs({
    this.zones,
    this.polygonPoints,
    this.surfaceHa,
    this.highlightZoneId,
  });
}

// ─────────────────────────────────────────────────────────
// ARGS NAVIGATION CAMÉRA
// Transportent le contexte zones à travers le flow analyse
// ─────────────────────────────────────────────────────────

class CameraArgs {
  final List<TerrainZone> zones;
  final String zoneAnalyseeId;

  const CameraArgs({
    required this.zones,
    required this.zoneAnalyseeId,
  });
}