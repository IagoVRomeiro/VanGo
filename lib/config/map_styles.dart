/// Estilo escuro do mapa para o modo navegação, com as vias em destaque
/// e pontos de interesse ocultos para reduzir a poluição visual.
const String navigationDarkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1d2026"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8a9099"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1d2026"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"visibility": "off"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry", "stylers": [{"color": "#24282f"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#3a3f48"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#15171b"}]},
  {"featureType": "road", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#c4c9d1"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#474d57"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#5a616d"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#1a1c20"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0f2233"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4e6d8c"}]}
]
''';
