import 'dart:convert';

class Employee {
  int? id;
  Map<String, String> staticFields;
  Map<String, String> dynamicFields;
  int? managerId;
  int? tabId;
  List<String> visibleFields;

  Employee({
    this.id,
    required this.staticFields,
    this.dynamicFields = const {},
    this.managerId,
    this.tabId,
    this.visibleFields = const [],
  });

  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'id': id,
      'managerId': managerId,
      'tabId': tabId,
      'dynamicFields': jsonEncode(dynamicFields),
      'visibleFields': jsonEncode(visibleFields),
    };
    map.addAll(staticFields);
    return map;
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'],
      staticFields: Map<String, String>.from(map['staticFields']),
      dynamicFields: map['dynamicFields'] != null
          ? Map<String, String>.from(jsonDecode(map['dynamicFields']))
          : {},
      managerId: map['managerId'],
      tabId: map['tabId'],
      visibleFields: map['visibleFields'] != null
          ? List<String>.from(jsonDecode(map['visibleFields']))
          : [],
    );
  }
}