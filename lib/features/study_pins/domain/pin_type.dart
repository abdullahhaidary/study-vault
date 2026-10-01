/// Persisted Study Pin kinds.
enum StudyPinType {
  point,
  text;

  String get dbValue => name;

  static StudyPinType fromDb(String value) {
    return StudyPinType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => StudyPinType.point,
    );
  }
}
