class OptionItem {
  final String label;
  final String value;

  const OptionItem({
    required this.label,
    required this.value,
  });

  factory OptionItem.fromDynamic(dynamic item) {
    if (item == null) {
      return const OptionItem(label: '', value: '');
    }
    if (item is OptionItem) {
      return item;
    }
    if (item is Map) {
      final val = (item['value'] ??
              item['_id'] ??
              item['id'] ??
              item['key'] ??
              item['slug'] ??
              item['name'] ??
              item['title'] ??
              item['label'] ??
              '')
          .toString();

      final lbl = (item['label'] ??
              item['name'] ??
              item['title'] ??
              item['text'] ??
              item['value'] ??
              val)
          .toString();

      return OptionItem(
        label: lbl.isNotEmpty ? lbl : val,
        value: val.isNotEmpty ? val : lbl,
      );
    }
    final str = item.toString();
    return OptionItem(label: str, value: str);
  }

  bool matches(String candidate) {
    final cand = candidate.trim().toLowerCase();
    return value.trim().toLowerCase() == cand || label.trim().toLowerCase() == cand;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OptionItem &&
          runtimeType == other.runtimeType &&
          (value.toLowerCase().trim() == other.value.toLowerCase().trim() ||
              label.toLowerCase().trim() == other.label.toLowerCase().trim());

  @override
  int get hashCode => value.toLowerCase().trim().hashCode;

  @override
  String toString() => 'OptionItem(label: $label, value: $value)';
}
