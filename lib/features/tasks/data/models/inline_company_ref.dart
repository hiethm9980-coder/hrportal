/// `company: { id, name }` on [GET /tasks] and [GET /projects] list items.
class InlineCompanyRef {
  final int id;
  final String name;

  const InlineCompanyRef({required this.id, this.name = ''});

  static InlineCompanyRef? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = (m['id'] as num?)?.toInt();
    if (id == null) return null;
    return InlineCompanyRef(
      id: id,
      name: m['name']?.toString() ?? '',
    );
  }
}
