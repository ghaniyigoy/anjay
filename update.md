# Update

Catatan perubahan terbaru pada aplikasi.

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
