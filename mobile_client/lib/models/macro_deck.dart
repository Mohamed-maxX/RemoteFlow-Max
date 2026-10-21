class MacroButton {
  final String id;
  final String label;
  final String icon;
  final String type; // 'hotkey', 'script', 'launch', 'url', 'text'
  final Map<String, dynamic> payload;
  final String color;

  const MacroButton({
    required this.id,
    required this.label,
    required this.icon,
    required this.type,
    required this.payload,
    required this.color,
  });

  factory MacroButton.fromMap(Map<String, dynamic> map) {
    return MacroButton(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      icon: map['icon'] as String? ?? 'bolt',
      type: map['type'] as String? ?? 'hotkey',
      payload: (map['payload'] as Map<String, dynamic>?) ?? {},
      color: map['color'] as String? ?? '#00E5FF',
    );
  }
}

class MacroDeck {
  final String id;
  final String name;
  final List<MacroButton> buttons;

  const MacroDeck({
    required this.id,
    required this.name,
    required this.buttons,
  });

  factory MacroDeck.fromMap(Map<String, dynamic> map) {
    final btnsRaw = map['buttons'] as List<dynamic>? ?? [];
    return MacroDeck(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Macro Deck',
      buttons: btnsRaw
          .map((b) => MacroButton.fromMap(b as Map<String, dynamic>))
          .toList(),
    );
  }
}
