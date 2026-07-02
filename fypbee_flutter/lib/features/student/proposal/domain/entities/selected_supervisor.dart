class SelectedSupervisor {
  final String uid;
  final String name;
  final String email;
  final int currentStudents;
  final int maxStudents;

  const SelectedSupervisor({
    required this.uid,
    required this.name,
    required this.email,
    required this.currentStudents,
    required this.maxStudents,
  });

  bool get isFull => currentStudents >= maxStudents;
}
