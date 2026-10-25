import 'package:flutter/widgets.dart';

/// One local study library on this device, with its own database and files.
@immutable
class LibraryAccount {
  const LibraryAccount({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
  });

  /// The original library in the app documents directory.
  static const defaultId = 'default';
  static const defaultName = 'Personal';
  static const maxNameLength = 40;

  final String id;
  final String name;
  final int colorIndex;
  final DateTime createdAt;

  bool get isDefault => id == defaultId;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    final letters = [
      for (final word in words.take(2))
        if (word.isNotEmpty) word.characters.first,
    ];
    return letters.isEmpty ? '?' : letters.join().toUpperCase();
  }

  LibraryAccount copyWith({String? name}) => LibraryAccount(
    id: id,
    name: name ?? this.name,
    colorIndex: colorIndex,
    createdAt: createdAt,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'color': colorIndex,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static LibraryAccount? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final color = json['color'];
    final created = DateTime.tryParse('${json['createdAt']}');
    if (id is! String ||
        name is! String ||
        name.trim().isEmpty ||
        color is! int ||
        created == null) {
      return null;
    }
    return LibraryAccount(
      id: id,
      name: name,
      colorIndex: color,
      createdAt: created,
    );
  }
}

/// Every account on this device and the one whose library is open.
@immutable
class LibraryAccounts {
  LibraryAccounts({
    required List<LibraryAccount> accounts,
    required this.activeId,
  }) : accounts = List.unmodifiable(accounts) {
    if (!this.accounts.any((a) => a.id == activeId)) {
      throw ArgumentError.value(activeId, 'activeId', 'Unknown account');
    }
  }

  final List<LibraryAccount> accounts;
  final String activeId;

  LibraryAccount get active => accounts.firstWhere((a) => a.id == activeId);

  LibraryAccount? byId(String id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }
}

class LibraryAccountException implements Exception {
  const LibraryAccountException(this.message);
  final String message;

  @override
  String toString() => message;
}
