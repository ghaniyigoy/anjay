# Update

Catatan perubahan terbaru pada aplikasi.

## Halaman "Make a Submission" (Start A New Submission)

Halaman `/submission/new` (langkah awal alur author "Start A New Submission") didesain ulang
menyerupai halaman submission OJS 3.x: card putih di tengah dengan background abu-abu muda,
tanpa sidebar.

### Fitur
- Judul **Make a Submission** (rata tengah) + bagian **Before you begin** dengan tiga paragraf panduan.
- Field **Title \*** (wajib diisi) dengan gaya focus ring sederhana.
- Fieldset **Submission Checklist \*** (5 poin checklist + link Author Guidelines) dan checkbox
  konfirmasi "Yes, my submission meets all of these requirements."
- Fieldset **Privacy Consent \*** dengan checkbox persetujuan data + link privacy statement.
- Tombol **Begin Submission** full-width (biru `#087b9c`) → setelah validasi lulus, membuat
  submission dan redirect ke wizard `tab=details`.
- Validasi client-side (JS): title wajib, kedua checkbox wajib dicentang; pesan error per-field
  + alert ringkasan; focus ke field pertama yang tidak valid. Ada juga guard server-side jika
  title kosong (form dirender ulang dengan pesan error).
- Responsive: desktop card 640px, tablet 90%, mobile hampir full-width dengan padding diperkecil.

### File yang diubah
- `lib/ojs_landing/submission.ex` — `create/2` (username, title) untuk menyimpan judul awal.
- `lib/ojs_landing_web/controllers/author_controller.ex` — `create_submission` menerima title,
  guard title kosong, tetap redirect ke wizard.
- `lib/ojs_landing_web/controllers/author_html/new_submission.html.heex` — template ditulis ulang
  (semantic HTML: `<main>`, `<form>`, `<fieldset>`, `<legend>`, `<label>`, `<input>`, `<button>`).
- `assets/css/app.css` — section `.submission-*` (card, fieldsets, input, tombol, error, responsive)
  + penyesuaian ukuran font tabel "My Submissions": isi sel 13px, judul naskah 12px.
- `test/ojs_landing_web/controllers/author_controller_test.exs` — 4 test baru (render halaman,
  auth redirect, create dengan title, guard title kosong).

### Status
- `mix precommit` lulus: 97 test, tanpa warning.

## Review Workflow: Submission → Review → Copyediting → Production → Published

Alur review kini berjalan penuh dari tahap 1 sampai publikasi. Setiap submit/publish tersimpan
di dalam memori (Agent) sehingga statusnya bertahan selama node berjalan.

### Tahap 2 → 3 (Review → Copyediting)
- `lib/ojs_landing/reviewer_assignment.ex` (baru): store `ReviewerAssignment` berbasis Agent.
  - `submit_review/2` — simpan rekomendasi & komentar, set `status: :completed`, `stage: :copyediting`, rekam ke `review_history`.
- `submit_review/2` di controller sebelumnya hanya redirect balik tanpa menyimpan apa pun — diperbaiki.
- Stage bar di halaman review dibuat dinamis: Review ditandai selesai (centang), Copyediting aktif.

### Tahap 3 → 4 (Copyediting → Production)
- Tugas copyediting (Initial, Author, Final) bisa ditandai selesai via `POST /review/:id/copyedit/:task`.
- Tombol **Proceed to Production** hanya muncul (dan divalidasi di server) setelah semua tugas copyediting selesai:
  `POST /review/:id/advance` → `stage: :production`.

### Tahap 4 → Published
- Panel Production: daftar **Galley Files** + form tambah galley (`POST /review/:id/galley`).
- Tugas proofreading (Author, Proofreader) via `POST /review/:id/proofread/:task`.
- Setelah semua proofread selesai, tersedia form **Publish Submission** (`POST /review/:id/publish`)
  dengan isian issue → `status: :published`, `published_at`, `issue`.
- Panel "Published" menampilkan issue, tanggal publikasi, dan jumlah galley.

### File yang diubah
- `lib/ojs_landing/reviewer_assignment.ex` — store baru (defstruct + seed + fungsi workflow).
- `lib/ojs_landing/application.ex` — daftarkan `OjsLanding.ReviewerAssignment`.
- `lib/ojs_landing_web/router.ex` — route baru: `advance`, `copyedit/:task`, `galley`, `proofread/:task`, `publish`.
- `lib/ojs_landing_web/controllers/reviewer_controller.ex` — aksi workflow + login guard.
- `lib/ojs_landing_web/controllers/reviewer_html/review.html.heex` — panel Copyediting, Production, Published; stage bar dinamis.
- `lib/ojs_landing_web/controllers/reviewer_html.ex` — helper `all_tasks_done?/1`, `done_task_count/1`, `stage_class/2`.
- `assets/css/app.css` — style task list, galley form, pill status, dll.
- `test/ojs_landing_web/controllers/reviewer_controller_test.exs` — 15 test workflow.

### Status
- `mix precommit` lulus: 93 test, tanpa warning.
