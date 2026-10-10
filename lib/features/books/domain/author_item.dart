class AuthorItem {
  final String lastName;
  final String firstName;

  const AuthorItem({required this.lastName, required this.firstName});

  String get displayName {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$last $first';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorItem &&
          runtimeType == other.runtimeType &&
          lastName.toLowerCase() == other.lastName.toLowerCase() &&
          firstName.toLowerCase() == other.firstName.toLowerCase();

  @override
  int get hashCode =>
      lastName.toLowerCase().hashCode ^ firstName.toLowerCase().hashCode;
}
