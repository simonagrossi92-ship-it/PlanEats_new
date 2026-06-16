class Recipe {
  final int id;
  final String title;
  final String image;

  Recipe({
    required this.id,
    required this.title,
    required this.image,
  });

  // Questo trasforma il JSON in un oggetto Recipe
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
    );
  }
}
