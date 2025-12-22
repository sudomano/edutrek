List<String> parseStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  } else if (value is String) {
    return [value];
  } else {
    return [];
  }
}
