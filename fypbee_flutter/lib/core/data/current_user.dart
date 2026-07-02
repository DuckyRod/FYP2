class CurrentUser {
  static String? uid;
  static String? id;
  static String? email;
  static String? role;
  static String? name;

  static void setUser(Map<String, dynamic> data) {
    uid = data['uid'];
    id = data['id'] ?? data['studentId'];
    email = data['email'];
    role = data['role'];
    name = data['name'];
  }

  static void clear() {
    uid = null;
    id = null;
    email = null;
    role = null;
    name = null;
  }
}
