# Update

Catatan perubahan terbaru pada aplikasi.

## Halaman "Make a Submission: Details" (OJS 3.5 PKP wizard)

Halaman baru `/submission/:id/details` (GET + POST) yang meniru langkah **Details** pada wizard
submission OJS 3.5 PKP: background abu-abu muda, konten di tengah (lebar ~90%), tanpa sidebar
maupun navbar.

### Fitur
- Breadcrumb **Dashboard / My Submissions / Submission {id}**.
- Header: judul **Make a Submission: Details** di kiri + tombol **Save for Later** di kanan
  (tombol submit yang terikat ke form via atribut `form=`).
- Card putih berisi progress step horizontal: **1 Details → 2 Upload Files → 3 Contributors →
  4 For the Editors → 5 Review**. Step aktif (Details) berwarna biru, step lain abu-abu.
- Card putih besar dengan layout 2 kolom:
  - Kiri: heading **Submission Details** + deskripsi singkat.
  - Kanan: form submission dengan field **Title \***, **Keywords** (deskripsi + input),
    **Abstract \*** (rich text editor dengan toolbar Bold, Italic, Superscript, Subscript,
    Link), dan **References** (deskripsi + textarea besar).
- Footer card: **Last saved 16 minutes ago**, **Cancel**, **Save for Later**, dan **Continue**
  (biru). `Continue` menyimpan lalu redirect ke wizard `tab=files`; `Save for Later` menyimpan
  lalu kembali ke My Submissions (incomplete).
- Validasi **Title \*** dan **Abstract \***: client-side (JS, merah + alert ringkasan) dan
  guard server-side (form dirender ulang dengan pesan error per-field).
- Rich text editor: `contenteditable` + toolbar `execCommand`, hasil HTML disinkronkan ke hidden
  input `submission[abstract]`.
- Responsive: desktop 2 kolom, tablet/mobile bertumpuk satu kolom.

### File yang diubah
- `lib/ojs_landing/submission.ex` — field `references` (struct + `update/2` + seed).
- `lib/ojs_landing_web/router.ex` — route `GET/POST /submission/:id/details`.
- `lib/ojs_landing_web/controllers/author_controller.ex` — aksi `details/2`, `save_details/2`
  (+ validasi `title`/`abstract`, redirect per aksi).
- `lib/ojs_landing_web/controllers/author_html.ex` — `references` di `submission_to_form/1`,
  `submission_params_to_form/1`, `details_steps/0`, `step_is_current?/1`.
- `lib/ojs_landing_web/components/layouts/submission.html.heex` — layout minimal (tanpa
  header/sidebar) untuk halaman ini.
- `lib/ojs_landing_web/controllers/author_html/details.html.heex` — template baru halaman.
- `assets/css/app.css` — section `.ojs-details-*`, `.ojs-progress-*`, `.ojs-richtext-*`,
  `.btn-ojs-link`, responsive.
- `assets/js/app.js` — inisialisasi rich text editor (toolbar + sync hidden input) dan
  validasi form.
- `test/ojs_landing_web/controllers/author_controller_test.exs` — 6 test baru (render, auth
  redirect, not-found, save + continue, save for later, validasi blank).

### Status
- `mix precommit` lulus: 103 test, tanpa warning.

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
