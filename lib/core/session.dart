// Session login: tenant + role + email user aktif.
// Diisi AuthService saat login; dibaca FirebaseService & UI untuk gating.
class AuthSession {
  static final AuthSession instance = AuthSession._();
  AuthSession._();

  String tenantId = 'qj-motor';
  String role = '';
  String email = '';
  String uid = '';

  bool get isLoggedIn => uid.isNotEmpty;
  bool get isOps => role == 'ops_manager' || role == 'super_admin';
  bool get isStaff => role == 'staff_gudang' || isOps;
  bool get isFrontdesk => role == 'frontdesk' || isOps;
  bool get isKepalaMekanik => role == 'kepala_mekanik' || isOps;
  bool get isAdminSales => role == 'admin_sales' || isOps;
  bool get canBookPDI => role == 'admin_sales' || role == 'frontdesk' || isOps;
  bool get canApprove => isOps;
  bool get canManageMaster => isStaff; // spareparts, rak, barcode, harga
  bool get canTransact => role == 'staff_gudang' || role == 'frontdesk' || role == 'kepala_mekanik' || isOps;
  // Daftarkan kode/part BARU via scan: hanya pengelola master (gudang + ops).
  bool get canCreatePart => isStaff;
  // Input hitung opname via scan: SEMUA HP terdaftar boleh (kecuali direksi read-only).
  // Buat sesi opname: staff/kepala/ops. Approve: ops saja.
  static const counterRoles = [
    'staff_gudang', 'frontdesk', 'kepala_mekanik', 'mekanik',
    'admin_sales', 'ops_manager', 'super_admin',
  ];
  bool get canCountOpname => isLoggedIn && counterRoles.contains(role);
  bool get canStandby => isLoggedIn && counterRoles.contains(role);
  bool get canStartOpname => isLoggedIn &&
      (role == 'staff_gudang' || role == 'kepala_mekanik' || isOps);
  // Lihat daftar peralatan: semua role penghitung. Kelola: staff/kepala/ops (di halaman).
  bool get canPeralatan => isLoggedIn && counterRoles.contains(role);
  // Jadwal bengkel (piket siang + pit sore): semua role penghitung.
  bool get canJadwal => isLoggedIn && counterRoles.contains(role);

  void clear() {
    tenantId = 'qj-motor';
    role = '';
    email = '';
    uid = '';
  }
}
