class TabModel {
  int? id; 
  String name;

  TabModel({this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id, 
      'name': name,
    };
  }

  static TabModel fromMap(Map<String, dynamic> map) {
    return TabModel(
      id: map['id'],
      name: map['name'],
    );
  }
}