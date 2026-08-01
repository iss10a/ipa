enum CatalogKind { movies, series }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.kind,
  });

  final String id;
  final String name;
  final CatalogKind kind;
}
