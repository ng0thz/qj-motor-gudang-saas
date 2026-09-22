import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../core/qj_theme.dart';
import '../../core/session.dart';

// Kelola user khusus Ops Manager — full dari web, tanpa CLI / tanpa Blaze.
// Buat user: pakai secondary FirebaseApp agar sesi Ops tidak tertendang,
// lalu tulis profil users/{uid} (tenant+role+aktif). Rules membaca profil
// ini sebagai fallback bila custom claims belum diset.
const List<String> kRoles = [
  'ops_manager',
  'staff_gudang',
  'frontdesk',
  'kepala_mekanik',
  'mekanik',
  'admin_sales',
  'direksi_readonly',
];

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _db = FirebaseFirestore.instance;
  String? _error;
  bool _busy = false;

  // Sinkron direktori team/{uid} (dipakai dropdown mekanik PDI) dari profil user.
  Future<void> _syncTeam(String uid, Map<String, dynamic> data) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final m = doc.data() ?? data;
      await _db
          .collection('tenants')
          .doc(AuthSession.instance.tenantId)
          .collection('team')
          .doc(uid)
          .set({
        'nama': '${m['nama'] ?? m['email'] ?? ''}',
        'email': '${m['email'] ?? ''}',
        'role': '${m['role'] ?? ''}',
        'aktif': m['aktif'] != false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> _watchUsers() {
    return _db
        .collection('users')
        .where('tenantId', isEqualTo: AuthSession.instance.tenantId)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
      list.sort((a, b) => '${a['email']}'.compareTo('${b['email']}'));
      return list;
    });
  }

  Future<void> _buatUser() async {
    final namaCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'staff_gudang';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Buat user baru'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: 'Nama')),
          const SizedBox(height: 8),
          TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 8),
          TextField(controller: passCtrl, obscureText: true,
              decoration: const InputDecoration(labelText: 'Password awal (min 6)', helperText: 'Sampaikan ke user, minta diganti')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: kRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => role = v ?? role,
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Buat')),
        ],
      ),
    );
    if (ok != true) return;
    if (emailCtrl.text.trim().isEmpty || passCtrl.text.length < 6) {
      setState(() => _error = 'Email wajib diisi, password min 6 karakter.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    FirebaseApp? secondary;
    try {
      secondary = await Firebase.initializeApp(
        name: 'useradmin-${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final cred = await FirebaseAuth.instanceFor(app: secondary).createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
      await _db.collection('users').doc(cred.user!.uid).set({
        'email': emailCtrl.text.trim(),
        'nama': namaCtrl.text.trim().isEmpty ? emailCtrl.text.trim() : namaCtrl.text.trim(),
        'tenantId': AuthSession.instance.tenantId,
        'role': role,
        'aktif': true,
        'dibuatOleh': AuthSession.instance.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _syncTeam(cred.user!.uid, {'role': role});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User ${emailCtrl.text.trim()} ($role) dibuat. Sampaikan password awal.')));
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.code == 'email-already-in-use'
          ? 'Email sudah terdaftar.'
          : e.code == 'weak-password'
              ? 'Password terlalu lemah.'
              : 'Gagal: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Gagal: $e');
    } finally {
      try {
        await secondary?.delete();
      } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAktif(Map<String, dynamic> u) async {
    final aktif = !(u['aktif'] != false);
    await _db.collection('users').doc(u['uid']).set(
        {'aktif': aktif, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await _syncTeam(u['uid'] as String, {});
  }

  Future<void> _gantiRole(Map<String, dynamic> u) async {
    String role = '${u['role'] ?? 'staff_gudang'}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Role ${u['email']}'),
        content: DropdownButtonFormField<String>(
          value: kRoles.contains(role) ? role : 'staff_gudang',
          items: kRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => role = v ?? role,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true) {
      await _db.collection('users').doc(u['uid']).set(
          {'role': role, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await _syncTeam(u['uid'] as String, {});
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Link reset dikirim ke $email')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'ops_manager':
      case 'super_admin':
        return QjColors.red;
      case 'staff_gudang':
        return QjColors.navy;
      case 'frontdesk':
        return const Color(0xFF0284C7);
      case 'kepala_mekanik':
        return const Color(0xFF7C3AED);
      case 'mekanik':
        return const Color(0xFF0E7C5B);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthSession.instance.isOps) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kelola User')),
        body: const Center(child: Text('Halaman ini khusus Ops Manager.')),
      );
    }
    return Scaffold(
      backgroundColor: QjColors.bg,
      appBar: AppBar(
        title: const Text('Kelola User'),
        backgroundColor: QjColors.navy,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _buatUser,
        backgroundColor: QjColors.red,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Buat User', style: TextStyle(color: Colors.white)),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: Column(children: [
        if (_error != null)
          Container(width: double.infinity, margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
        if (_busy) const LinearProgressIndicator(),
        const Padding(padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text('User baru langsung bisa login. Hapus total butuh CLI (tools/create_user.js).',
                style: TextStyle(fontSize: 11, color: Colors.grey))),
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _watchUsers(),
          builder: (c, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            if (s.data!.isEmpty) return const Center(child: Text('Belum ada user di tenant ini.'));
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: s.data!.length,
              itemBuilder: (_, i) {
                final u = s.data![i];
                final aktif = u['aktif'] != false;
                final role = '${u['role'] ?? '-'}';
                return Card(child: ListTile(
                  leading: CircleAvatar(backgroundColor: _roleColor(role).withOpacity(0.15),
                      child: Icon(Icons.person, color: _roleColor(role), size: 20)),
                  title: Text('${u['nama'] ?? u['email']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text('${u['email']}\n$role${aktif ? '' : ' • NONAKTIF'}',
                      style: TextStyle(fontSize: 11, color: aktif ? Colors.grey : Colors.red)),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'toggle') _toggleAktif(u);
                      if (v == 'role') _gantiRole(u);
                      if (v == 'reset') _resetPassword('${u['email']}');
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'toggle', child: Text(aktif ? 'Nonaktifkan' : 'Aktifkan')),
                      const PopupMenuItem(value: 'role', child: Text('Ganti role')),
                      const PopupMenuItem(value: 'reset', child: Text('Kirim link reset password')),
                    ],
                  ),
                ));
              },
            );
          },
        )),
      ]))),
    );
  }
}
