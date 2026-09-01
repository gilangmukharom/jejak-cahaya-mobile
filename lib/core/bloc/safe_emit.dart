import 'package:bloc/bloc.dart';

/// Membuang state yang dipancarkan setelah cubit ditutup, alih-alih melempar.
///
/// Hampir setiap operasi di aplikasi ini berbentuk "minta ke server, tunggu,
/// lalu pancarkan hasilnya". Di antara `await` dan `emit` itu ada jeda yang bisa
/// mencapai beberapa detik — dan selama jeda tersebut pemain bebas berpindah
/// layar, menekan tombol kembali, atau keluar dari sesi. Ketika itu terjadi
/// cubit-nya sudah ditutup, sementara permintaan yang terlanjur berjalan tetap
/// selesai dan tetap memanggil `emit`.
///
/// Tanpa penjagaan ini, akibatnya adalah:
///
/// ```
/// Unhandled Exception: Bad state: Cannot emit new states after calling close
/// ```
///
/// Pengecualian itu muncul dari dalam Future yang tidak ada yang menunggunya,
/// jadi ia tidak bisa ditangkap oleh `try/catch` mana pun di layar — ia langsung
/// menjadi galat tak tertangani di seluruh aplikasi.
///
/// Menjatuhkan state-nya diam-diam adalah perilaku yang benar di sini: kalau
/// cubitnya sudah ditutup, tidak ada lagi layar yang menunggu hasil itu.
/// Menambahkan `if (isClosed) return;` pada setiap `emit` juga menyelesaikan
/// masalah, tetapi menaruhnya di satu tempat berarti tidak ada `emit` baru yang
/// bisa lupa memasangnya.
mixin SafeEmit<S> on BlocBase<S> {
  @override
  void emit(S state) {
    if (isClosed) return;
    super.emit(state);
  }
}
