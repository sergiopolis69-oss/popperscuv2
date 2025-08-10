class ClientModel {
  final int id;
  final String name;
  final String? phone;
  final String? email;

  ClientModel({required this.id, required this.name, this.phone, this.email});

  factory ClientModel.fromMap(Map<String,dynamic> m) => ClientModel(
    id: m['id'] as int,
    name: (m['name'] ?? '').toString(),
    phone: m['phone']?.toString(),
    email: m['email']?.toString(),
  );
}
