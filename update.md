# Update

Catatan perubahan terbaru pada aplikasi.

## Halaman "Make a Submission" (`/submission/new`): field Section, Language, dan Comments to the Editor dihapus

Field **Section \***, **Language \***, dan **Comments to the Editor** dihapus dari form
awal submission (`/submission/new`). Form kini hanya berisi **Title \***, **Submission
Checklist** (required), **Privacy Consent** (required), dan tombol Begin Submission.

Backend tetap memakai nilai default saat field tersebut tidak dikirim: `section` →
`"Artikel Penelitian"`, `language` → `"id"`, `comments_to_editor` → `""` (default di
`OjsLanding.Submission.create/2`), sehingga tidak ada perubahan pada controller maupun
model.

### File yang diubah
- `lib/ojs_landing_web/controllers/author_html/new_submission.html.heex` — blok field
  Section, Language, dan Comments to the Editor dihapus.

### Status
- Template dikompilasi ulang; request ke `/submission/new` tampil tanpa ketiga field
  tersebut (perlu hard-refresh Ctrl+F5).

## My Submissions: tombol "View" menghubungkan ke editor workflow page

Tombol **View** pada `/dashboard/mySubmissions` tidak lagi membuka wizard submission
(`/submission/wizard/:id?tab=...`), melainkan membuka **editor workflow page**
(`/dashboard/editorial?workflowSubmissionId=<id>&currentViewId=...&workflowMenuKey=...`)
sesuai stage submission — konsisten dengan tombol View di editorial dashboard.

- Stage `initial_review`/belum review → `workflow_1` (Submission).
- Stage review (`external_review`, `needs_reviews`, `awaiting_reviews`, `reviews_submitted`,
  `revisions_submitted`) → `workflow_3_1` (External Review).
- Stage `copyediting` → `workflow_4`.
- Stage `production` → `workflow_5`.
- Submission status `:incomplete` tetap menampilkan tombol **Continue** yang membuka wizard
  detail (`?tab=details`).

### File yang diubah
- `lib/ojs_landing_web/controllers/author_html.ex` — helper `submission_workflow_path/2` (URL
  workflow + `workflow_menu_for_stage/1` meniru `default_workflow_menu_for_stage` editor).
- `lib/ojs_landing_web/controllers/author_html/my_submissions.html.heex` — link View memakai
  `submission_workflow_path/2`.

### Status
- `mix compile` sukses; route workflow mengembalikan HTTP 200 untuk submission yang aktif.

## Manage Issues: tombol "Create Issue" berfungsi (modal form + persist)

Tombol **Create Issue** pada `/informatika/manageIssues` (dan tab Future Issues) sebelumnya
hanya `<button>` bawaan tanpa aksi — kini berfungsi penuh.

### Fitur
- Klik **Create Issue** membuka **modal form** untuk mengisi **Title \*** (wajib), **Volume**,
  **Number**, dan **Year**.
- **Save** mengirim POST ke `POST /:journal_path/manageIssues` → `SettingsController.create_issue/2`
  → `Issue.create/2`, lalu redirect balik ke list dengan flash sukses. Volume/number/year
  diisi default otomatis (mengikuti issue terbaru journal) bila dikosongkan.
- Issue baru berstatus `:scheduled` (muncul di **Future Issues**).
- **Cancel** / klik overlay menutup modal tanpa menyimpan.
- `Issue` diubah dari data statis menjadi **Agent store** (in-memory) sehingga issue yang baru
  dibuat bertahan antar-request (resets saat server restart).

### File yang diubah
- `lib/ojs_landing/issue.ex` — diubah menjadi Agent store (`start_link`, `all/0`, `get/1`,
  `for_journal/1`, `current/1` membaca dari Agent) + fungsi `create/2` (validasi title,
  next_id, penentuan volume/number/year default).
- `lib/ojs_landing/application.ex` — daftarkan `OjsLanding.Issue` di supervisor.
- `lib/ojs_landing_web/router.ex` — route `post "/manageIssues"`.
- `lib/ojs_landing_web/controllers/settings_controller.ex` — aksi `create_issue/2`.
- `lib/ojs_landing_web/controllers/settings_html/manage_issues.html.heex` — tombol gave
  `onclick="openCreateIssue()"`; modal create issue (overlay + form + footer); fungsi JS
  `openCreateIssue`/`closeCreateIssue` (exposed ke `window`).
- `assets/css/app.css` — gaya `.manage-issue-*` (overlay, modal, field, footer).

### Status
- `mix precommit` lulus: 150 test, tanpa warning.
- `mix assets.build` sukses (asset CSS/JS ulang).

## Review Step 3: komentar "For Author and Editor" & "For Editor" tidak hilang setelah upload file

### Bug
- Pada halaman review step 3 (Download & Review), teks yang diketik di rich text editor
  **For Author and Editor** (`comments_author`) dan **For Editor** (`comments_editor`)
  hilang setelah mengunggah file Review (mis. lewat tombol **Upload File** di panel
  **Reviewer Files**).
- **Penyebab:** konten `contenteditable` hanya di-sinkronkan ke hidden input ketika form
  `#review-form` di-submit (Submit Review). Form upload Review memakai form POST terpisah
  (`POST /review/:id/file`) yang memicu *full page reload*, sehingga teks yang belum
  tersinkronisasi hilang.

### Perbaikan
- **Auto-save draft lokal:** saat user mengetik, isi editor kini ikut disimpan ke
  `localStorage` dengan key per-assignment & per-field
  (`review-draft-{id}-author` / `review-draft-{id}-editor`).
- **Restore setelah reload:** saat halaman dimuat ulang (mis. setelah upload/discussion),
  isi editor dipulihkan dari `localStorage` jika tersedia, sehingga komentar tidak hilang.
- **Hapus draft saat submit:** draft dihapus dari `localStorage` hanya ketika `#review-form`
  benar-benar di-submit (Submit Review), bukan saat form upload/discussion.

### File yang diubah
- `assets/js/app.js` — `initRichtextEditors/0`: dukungan `data-autosave` (simpan/restore draft
  ke `localStorage` pada `sync/0`; hapus saat form submit).
- `lib/ojs_landing_web/controllers/reviewer_html/review.html.heex` — tambah `data-autosave`
  pada kedua editor review step 3.

### Status
- `mix precommit` lulus: 150 test, tanpa warning.
- `mix assets.build` sukses (asset ulang).

## Review Step 3 (Download & Review): tombol aksi disederhanakan + perbaikan state "Go Back"

### 1. Tombol aksi pada Step 3 (Download & Review)
- Footer actions bawah-kanan pada halaman review step 3 diubah menjadi hanya **Go Back**,
  **Save For Later**, dan **Submit Review** (tombol terpisah **Continue to Step #4** dihapus).
- **Submit Review** pada step 3 kini **memajukan wizard ke Step 4 (Completion)** — sebelumnya
  langsung menyelesaikan review (POST `/review/:id` → `submit_review/2`).
- Agar data yang diketik (rekomendasi + komentar) tidak hilang saat maju ke step 4, `#review-form`
  pada step 3 diubah action-nya menjadi `POST /review/:id/step`. Rekomendasi (`<select
  form="review-form">`) dan komentar (hidden input hasil sinkronisasi rich text editor) ikut
  terkirim, lalu `advance_review_step/2` mem-persist-nya ke assignment.
- Step 4 (Completion) tetap punya tombol **Submit Review** miliknya sendiri yang benar-benar
  menyelesaikan review (`submit_review/2` → status `:completed`, stage `:copyediting`).

### 2. Perbaikan bug: halaman step 3 menampilkan form "Review Submission" (fallback)
- **Gejala:** `status: :in_progress` dengan `wizard_step: 1` tidak cocok dengan branch mana pun
  di template, sehingga jatuh ke cabang fallback `true ->` yang menampilkan form polos
  "Review Submission" (Quality Criteria, radio Yes/No/Maybe, dst.). Keadaan ini bisa terjadi
  setelah mengklik **Go Back** di salah satu step wizard: `go_back_review_step/1` selalu
  mengembalikan `wizard_step: 1` sehingga halaman patah.
- **Perbaikan:**
  - `lib/ojs_landing/reviewer_assignment.ex` — `go_back_review_step/1` kini mundur **satu step**
    (4 → 3, 3 → 2, 2 → 1) via `max(step - 1, 1)` alih-alih selalu reset ke 1. Klik **Go Back**
    dari Download & Review (step 3) kini kembali ke Guidelines (step 2).
  - `lib/ojs_landing_web/controllers/reviewer_html/review.html.heex` — branch `:in_progress`
    diperluas menjadi `wizard_step in [1, 2, 3]`, dengan step 1 dan 2 dirender sebagai
    Guidelines. Dengan begitu kombinasi `:in_progress` + `wizard_step: 1` tidak lagi menimpa
    form fallback.

### File yang diubah
- `lib/ojs_landing/reviewer_assignment.ex` — `advance_review_step/2` (untuk mem-persist
  rekomendasi/komentar saat maju), `go_back_review_step/1` (mundur satu step).
- `lib/ojs_landing_web/controllers/reviewer_html/review.html.heex` — action `#review-form` ke
  `/step`; footer step 3 (Go Back / Save For Later / Submit Review); branch step 1 sebagai
  Guidelines.
- `lib/ojs_landing_web/controllers/reviewer_controller.ex` — `review_step/2` meneruskan params
  ke `advance_review_step/2`.

### Status
- `mix test test/ojs_landing_web/controllers/reviewer_controller_test.exs` lulus: 18 test.
- `mix format --check-formatted` bersih.

## Review `/review/:id`: halaman menampilkan wizard review (stepper) + panel editor dihapus dari halaman reviewer

### 1. Tidak lagi "Respond to request" untuk assignment demo

- Seed assignment ID 1 diubah dari `status: :action_required` menjadi `:in_progress` dengan
  `wizard_step: 2`. Membuka `/review/1` kini langsung menampilkan wizard review proses
  (Guidelines → Download & Review → Completion), bukan halaman "Respond to request"
  (Accept/Decline). Flow Accept/Decline tetap ada dan teruji lewat assignment ID 4.
- Stepper 4 tahap (Request / Guidelines / Download & Review / Completion) selalu dirender di
  halaman `/review/:id` untuk menunjukkan progres reviewer.

### 2. Panel workflow EDITOR tidak lagi muncul di halaman reviewer

- Panel **Copyediting** (tugas initial/author/final) dan **Production** (galley, proofreading,
  publish) sebelumnya ikut dirender pada `/review/:id` saat status `:completed` (karena stage
  assignment = copyediting/production). Ini salah secara konsep OJS — tugas copyediting &
  production adalah tanggung jawab editor, bukan reviewer.
- Kedua panel tersebut dihapus dari halaman reviewer. Saat review selesai (status `:completed`),
  halaman hanya menampilkan panel "Review Submitted" (rekomendasi + komentar) + tombol
  "Back to My Assignments". Operasi store-nya (copyediting, advance, galley, proofread, publish)
  tetap ada dan teruji.
- Stage bar (Submission / Review / Copyediting / Production) dihapus dari halaman reviewer.

### 3. Helper & file

- `lib/ojs_landing/reviewer_assignment.ex` — seed ID 1 → `:in_progress`, `wizard_step: 2`.
- `lib/ojs_landing_web/controllers/reviewer_html/review.html.heex` — stepper selalu tampil;
  branch `:completed` hanya menampilkan "Review Submitted" (tanpa panel copyediting/production);
  stage bar dihapus; formulir "Review Submission" tetap di branch fallback.
- `lib/ojs_landing_web/controllers/reviewer_html.ex` — helper `wizard_current_step/1`
  dikembalikan ke logika semula (action_required = step 1); helper `stage_class/2` yang tak
  terpakai dihapus.
- `test/ojs_landing_web/controllers/reviewer_controller_test.exs` — test disesuaikan dengan
  seed baru (flow accept diarahkan ke assignment 4); test memastikan panel editor tidak muncul
  di halaman reviewer.

### Status
- `mix precommit` lulus: 147 test, tanpa warning.

## Reviewer `/review/:id`: Upload/Search/Discussion berfungsi + lanjut Step #4 (Completion)

### 1. Kontrol Upload / Search / Add Discussion yang tadinya non-fungsional kini berfungsi

Pada halaman review step 3 (Download & Review), tombol-tombol:

- **Search** (Review Files & Reviewer Files) — menampilkan input pencarian yang memfilter baris
  tabel file secara real-time berdasarkan nama/tipe (client-side, tanpa reload).
- **Upload File** (panel Reviewer Files) — membuka modal dengan input file sungguhan
  (`multipart/form-data`). Submits ke `POST /review/:id/file` → `add_reviewer_file/2`.
- **Add Discussion** — membuka modal (Subject + Message). Submits ke `POST /review/:id/discussion`
  → `add_discussion/2`. Diskusi tampil sebagai daftar thread lengkap dengan badge jumlah.
- Panel **Upload** (bagian atas) diubah hanya menjadi teks — tombol "Upload File" di dalamnya
  dihapus per permintaan; unggah file cukup lewat tombol di panel Reviewer Files.

### 2. Alur lanjut dari Step 3 ke Step 4 (Completion)

- **Continue to Step #4** — ditambahkan pada footer actions step 3 (POST ke `/review/:id/step`,
  memajukan wizard 3 → 4).
- **View Step 4 "Completion"** — baru: untuk `status :in_progress, wizard_step == 4` dirender
  ringkasan (Recommendation, Comments to Author/Editor) + tombol **Submit Review** (POST ke
  `/review/:id`) dan **Go Back to Review** (POST ke `/review/:id/go-back`).
- **Submit Review** langsung dari step 3 tetap berfungsi.

### File yang diubah
- `lib/ojs_landing/reviewer_assignment.ex` — field baru `reviewer_files` & `discussions`;
  fungsi `add_reviewer_file/2` & `add_discussion/2` (tahan `nil`); helper id berikutnya.
- `lib/ojs_landing_web/controllers/reviewer_controller.ex` — aksi `add_reviewer_file/2` &
  `add_discussion/2`; helper `humanize_size/1` & `file_type_from_name/1` untuk file upload.
- `lib/ojs_landing_web/router.ex` — route baru `post "/review/:id/file"` dan
  `post "/review/:id/discussion"`.
- `lib/ojs_landing_web/controllers/reviewer_html/review.html.heex` — panel Reviewer Files
  menampilkan `reviewer_files`; panel Review Discussions menampilkan `discussions`; modal upload
  & diskusi; search bar; tombol **Continue to Step #4**; view baru step 4 Completion; inline JS
  (buka/tutup modal, filter pencarian, tutup saat klik overlay).
- `lib/ojs_landing_web/controllers/reviewer_html.ex` — helper `reviewer_files/1` & `discussions/1`
  (nil-safe).
- `assets/css/app.css` — gaya `.rp-search-bar`, `.rp-discussion-*`, `.rp-modal-*`, `.rp-field-*`,
  `.rp-file-meta`, `.rp-badge-count`, `.rp-btn-sm`.
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — tautan "Open production
  record" diubah dari `.btn-view` ke `.editorial-view-link` agar teks tidak putih.

### Status
- `mix precommit` lulus: 147 test, tanpa warning.

## Review `/review/:id`: sidebar kanan dihapus + Wizard bertahap (Request → Guidelines → Download & Review → Completion)

### 1. Sidebar kanan dihapus
- Pada `review.html.heex`, seluruh `<aside class="review-side-col">` (yang berisi panel **Submission**, **Review Files**, dan **Review History**) dihapus.
- `.review-layout` di `assets/css/app.css` diubah dari grid 2 kolom (`minmax(0, 1fr) 320px`) menjadi `display: block` sehingga kolom konten melebar penuh.

### 2. Wizard bertahap (step-by-step)
Halaman review kini berjalan langkah demi langkah sesuai stepper:

1. **Request** (`:action_required`) — tombol **Accept Review** / **Decline Review**.
2. **Guidelines** — pedoman review + tombol **Continue to Download & Review**.
3. **Download & Review** — tabel file submission + tombol **Continue to Completing the Review**.
4. **Completion** — form review lengkap (Recommendation, kriteria, komentar).

Sebelumnya, setelah Accept halaman langsung lompat ke form review (melewati Guidelines dan Download & Review).

#### File yang diubah
- `lib/ojs_landing/reviewer_assignment.ex` — field baru `wizard_step` pada struct; seed data tiap assignment diisi `wizard_step` (assignment `:action_required` → 1, lainnya → 4); `accept_assignment/1` kini menetapkan `wizard_step: 2`; fungsi baru `advance_review_step/1` (hanya saat `:in_progress` dengan step 2/3 → +1).
- `lib/ojs_landing_web/controllers/reviewer_controller.ex` — aksi baru `review_step/2` (`POST /review/:id/step`) yang memanggil `advance_review_step/1`.
- `lib/ojs_landing_web/router.ex` — route baru `post "/review/:id/step"`.
- `lib/ojs_landing_web/controllers/reviewer_html/review.html.heex` — stepper dinamis ditampilkan untuk `:action_required` dan `:in_progress`; klausa `:in_progress` dengan `wizard_step in [2, 3]` untuk menampilkan panduan & daftar file.
- `lib/ojs_landing_web/controllers/reviewer_html.ex` — helper `wizard_current_step/1` dan `wizard_step_class/2`.
- `assets/css/app.css` — gaya `.rr-step.done` (centang hijau) dan `.rr-guideline-list`.
- `test/ojs_landing_web/controllers/reviewer_controller_test.exs` — update test (pending & accept) + test baru alur step (Guidelines → Download → Completion, dan tolak advance tanpa accept).

### Status
- `mix test` lulus: 147 test, tanpa warning.
- `mix precommit` lulus.

## Review Request Page: tampilan `/review/:id` untuk status action_required

Halaman `/review/:id` untuk assignment berstatus `:action_required` diubah dari panel sederhana
menjadi **Review Request Page** bergaya OJS, dengan header + stepper khusus.

### Fitur
- Header di kiri menampilkan **"Review: {judul submission}"** beserta subtitle (Round · Due) —
  hanya untuk status `:action_required`; status lain tetap memakai header & stage bar lama.
- Stepper 4 langkah: **1. Request** (aktif) · **2. Guidelines** · **3. Download & Review** ·
  **4. Completion**.
- **Section 1 — Request for Review**: paragraf *"You have been selected as a potential reviewer
  of the following submission..."* lalu meta list **Article Title**, **Abstract**, dan
  **Review Type** (Round).
- **Section 2 — Review Files**: kotak dengan header **Review Files** di kiri dan tombol
  **Search** di kanan (sejajar); tabel berisi kolom **Files**, **Date**, dan **Type** (badge
  tipe: pdf/csv/other), lalu tautan **View All Submission Details** di bawahnya.
- **Section 3 — Review Schedule**: grid **Editor's Request** (kiri) / **Response Due Date**
  (tengah) / **Review Due Date** (kanan), tautan **About Due Dates**, checkbox persetujuan
  *"Yes, I agree to have my data collected and stored according to the privacy statement."*
- Aksi kanan bawah: **Decline Review Request** dan **Accept Review, Continue to Step #2**
  (POST ke `/review/:id/decline` dan `/review/:id/accept` seperti sebelumnya).

### File yang diubah
- `lib/ojs_landing_web/controllers/reviewer_html/review.html.heex` — header/stepper khusus
  untuk `:action_required` + tiga section Review Request Page; blok status `:action_required`
  lama diganti.
- `assets/css/app.css` — section `.rr-*` (header, stepper, section, meta list, files table,
  schedule grid, consent, actions).

### Status
- `mix assets.build` sukses (template & CSS dikompilasi ulang).

## Reviewer Assignments: kolom Editorial Activity + aksi Respond to request + fix CSS

Perbaikan tampilan dan isi tabel pada `/dashboard/reviewAssignments`.

### Fitur
- **Kolom Editorial Activity**: assignment berstatus `:action_required` kini menampilkan
  **"Please accept or decline this request by {due_date}"** (gaya italic merah).
- **Kolom Actions**: tombol **Review** diganti **"Respond to request"** untuk assignment
  `:action_required`; status lain tetap "Review".
- **Perbaikan CSS**:
  - Judul artikel di kolom **SUBMISSIONS** tidak lagi besar/bold — `.submission-title` pada
    konteks reviewer dipaksa `14px` / weight 400 / Noto Sans (menimpa global 30px Noto Serif).
  - Kolom **ACTIONS** bukan lagi kotak biru — `.btn-view` pada konteks reviewer diubah menjadi
    tautan teks biru polos (tanpa background/padding/border-radius/box-shadow).

### File yang diubah
- `lib/ojs_landing_web/controllers/reviewer_html/review_assignments.html.heex` — kolom
  Editorial Activity & label aksi disesuaikan dengan status.
- `assets/css/app.css` — `.reviewer-main-content .submission-title`, `.reviewer-main-content
  .btn-view`, dan `.reviewer-main-content .response-request`.

### Status
- `mix assets.build` sukses.

## Editorial Dashboard: Assign Editor untuk semua stage + Predefined Message + Action Panel workflow_1

Kumpulan perbaikan pada alur editorial dashboard dan workflow view.

### Bug: "Assign Editor" tidak muncul untuk submission di stage awal tanpa editor
- **Sebelum:** `editorial_actions/1` hanya menampilkan **Assign Editor** bila `row.stage ==
  :submission and not row.has_editor`. Submission yang sudah di stage lain (mis. `initial_review`)
  tapi belum punya editor jatuh ke cabang lain sehingga menampilkan **Assign Reviewers** padahal
  belum ada editor yang menangani.
- **Sesudah:** pengecekan diubah menjadi `not row.has_editor` saja (diutamakan, terlepas dari
  stage). Karena proses review/keputusan editorial tidak bisa dimulai sebelum editor ditugaskan,
  submission tanpa editor selalu menampilkan **Assign Editor** di kolom **Editorial Activity**.

### Dropdown "Predefined Message" di modal Assign Participant
- Modal **Assign Participant** (`editorial.html.heex`) kini punya dropdown **Predefined Message**
  (`#ap-predefined-message`) antara teks hint dan label Message, berisi opsi:
  - **Discussion (Submission)** — mengisi rich text editor dengan pesan pembahasan submission.
  - **Assign Editor** — mengisi rich text editor dengan pesan penugasan editor.
- Ditambahkan fungsi JS `applyPredefinedMessage/1` yang mengisi editor sesuai pilihan; dropdown
  di-reset setiap kali modal dibuka.

### Action Panel workflow_1: ketiga tombol tampil & berfungsi
- Action Panel pada `workflowMenuKey=workflow_1` kini menampilkan dan menghubungkan ketiga aksi:
  - **Send For Review** — form POST ke `/dashboard/editorial/:id/send-to-review`.
  - **Accept and Skip Review** — sebelumnya hanya `<button type="button">` tanpa aksi (tidak
    berfungsi); diubah menjadi form POST ke `/dashboard/editorial/:id/accept`
    (`accept_submission/2`).
  - **Decline Submission** — form POST ke `/dashboard/editorial/:id/decline` dengan konfirmasi.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html.ex` — `editorial_actions/1`: kondisi "Assign
  Editor" menjadi `not row.has_editor`.
- `lib/ojs_landing_web/controllers/editor_html/editorial.html.heex` — dropdown Predefined
  Message + fungsi JS `applyPredefinedMessage/1` + reset saat modal dibuka.
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — Action Panel workflow_1
  (Accept and Skip Review menjadi form POST, struktur form Decline diperbaiki).
- `AGENTS.md` — dokumentasi urutan `editorial_actions/1` diperbarui (Assign Editor dicek
  pertama, terlepas dari stage).

### Status
- `mix precommit` lulus: 145 test, tanpa warning.

## Add Reviewer Panel (modal) dari tombol "Assign Reviewers" di Editorial Dashboard

Pada `/dashboard/editorial?currentViewId=active`, tombol **Assign Reviewers** di kolom
**Editorial Activity** tidak lagi berpindah ke halaman workflow, melainkan membuka **panel modal
"Add Reviewer"** untuk menetapkan reviewer bagi submission.

### Fitur
- Header modal dengan judul **Add Reviewer** di kiri dan tombol **close** (×) di kanan.
- Panel **Submission Author List**: menampilkan avatar inisial, nama author, dan judul submission.
- Heading **Locate a Reviewer** dengan tombol aksi **Search** dan **Filters** di sebelah kanannya.
- Daftar reviewer (tabel) berisi kolom **Reviewer** (nama + email), **Affiliation**, **Review
  Count**, **Last Review**, dan **Status** (Available / Busy).
- Pada baris reviewer, di sebelah kanan terdapat tombol **Select Reviewer** dan tombol dropdown
  (⋯) untuk aksi tambahan.
- Footer **Alternative Actions** dengan tombol **Create New Reviewer** dan **Enroll Existing User**.
- "Select Reviewer" mengirim assignment ke `POST /dashboard/editorial/:id/assign-reviewer`
  (dengan `reviewer_name`), lalu kembali ke dashboard view yang sama.
- Daftar reviewer disusun dari pengguna berperan reviewer/editor, dilengkapi metrik reviewer
  (jumlah review, last review, status) yang dihitung dari data `ReviewerAssignment`.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html.ex` — aksi `editorial_actions/1` untuk "Assign
  Reviewers" kini memakai `modal: "assign-reviewers-<id>"`; `latest_reviewer/1` fallback ke
  `reviewer_name` assignment.
- `lib/ojs_landing_web/controllers/editor_controller.ex` — `reviewer_json/1` + helper metrik
  reviewer; assign `ap_submissions_json` (id/title/author); `assign_reviewer/2` menerima
  `reviewer_name` dan redirect balik ke view dashboard.
- `lib/ojs_landing_web/controllers/editor_html/editorial.html.heex` — modal Add Reviewer + form
  POST tersembunyi + JS (render/filter reviewer, Select Reviewer, dropdown).
- `lib/ojs_landing/reviewer_assignment.ex` — field baru `reviewer_name` pada assignment.
- `assets/css/app.css` — gaya `.ar-*` (modal, author panel, tabel reviewer, status, footer
  Alternative Actions).
- `test` — `mix precommit` lulus.

### Status
- `mix precommit` lulus: 145 test, tanpa warning.

## Tab For the Editor: kolom kanan menjadi rich text editor "Comments For The Editor"

Tab **For the Editor** (`/submission/wizard/:id?tab=editors`) pada halaman wizard controller:
kolom kanan tidak lagi menampilkan daftar editor dan kotak *Request Editor*, melainkan
**rich text editor** dengan judul **Comments For The Editor** untuk menulis komentar bagi
editor (mis. submission terkait atau publikasi sebelumnya).

### Fitur
- Judul field **Comments For The Editor** + deskripsi singkat di atas editor.
- Rich text editor ala OJS sama seperti editor Abstract: toolbar **Bold**, **Italic**,
  **Superscript**, **Subscript**, dan **Link** dengan area `contenteditable` + placeholder.
- Isi tersimpan ke `submission[editor_comments]` (hidden input disinkronkan saat mengetik
  maupun saat form disubmit) via `Save for Later`/`Continue` pada tab ini.
- Komentar yang sudah tersimpan tampil kembali saat halaman dibuka, dan kini bisa
  dikosongkan kembali.
- JS rich text editor di `app.js` digeneralisasi: satu initializer untuk semua editor
  `.ojs-richtext[data-target]` (editor abstract tab Details tetap berfungsi).

### File yang diubah
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — konten kolom kanan
  tab editors diganti form rich text editor; blok JS "Add editor card" yang mati dihapus.
- `assets/js/app.js` — `initOjsDetails` direfaktor menjadi `initRichtextEditors` yang generik
  (mendukung banyak editor per halaman, sinkron hidden input juga saat submit).
- `lib/ojs_landing/submission.ex` — `update/2`: `editor_comments` ditangani `maybe_put_cleared`
  agar komentar bisa dikosongkan (sebelumnya string kosong diabaikan oleh `maybe_put`).
- `test/ojs_landing_web/controllers/author_controller_test.exs` — test tab editors kini
  mengecek `editor-comments-editor`.

### Status
- `mix precommit` lulus: 136 test, tanpa warning.

## Perbaikan: Edit contributor default author di tab Contributors

**Bug:** pada `/submission/wizard/:id?tab=contributors&view=edit&contributor_id=N` untuk submission
baru yang belum punya contributor, form edit tidak muncul padahal URL sudah benar. Sebabnya
`find_contributor/3` hanya mencari di daftar contributor yang sudah tersimpan; padahal tampilan
list menampilkan *default author* (pengguna yang login, id = `user.id`) yang disintesis oleh
`display_contributors/2` dan belum tersimpan di data submission. Akibatnya `editing_contributor`
bernilai `nil` dan form tidak dirender. Menyimpan hasil edit juga gagal karena
`update_contributor/3` tidak membuat contributor baru jika belum ada.

### Perbaikan
- `lib/ojs_landing_web/controllers/author_controller.ex` — `find_contributor/4` kini menerima
  `user`; jika submission belum punya contributor dan `contributor_id` cocok dengan `user.id`,
  mengembalikan default author sehingga form edit tampil.
- `lib/ojs_landing/submission.ex` — `update_contributor/3` kini *upsert*: bila contributor
  dengan id tersebut belum ada, contributor baru dibuat dari field yang dikirim.
- `lib/ojs_landing_web/controllers/author_html.ex` — `default_contributor/1` melengkapi semua
  field baru (`preferred_public_name`, `country`, `url`, `bio_statement`, `affiliation`,
  `public_list`) agar template edit tidak error `KeyError`.
- `test/ojs_landing_web/controllers/author_controller_test.exs` — test baru: edit view merender
  form untuk default author submission baru, dan meng-update default author tersimpan.

### Status
- `mix precommit` lulus: 134 test, tanpa warning.

## Contributors: form Edit lengkap ala OJS (10 field)

Form **Edit** contributor pada langkah **Make a Submission: Contributors** kini menampilkan
seluruh field profil ala OJS 3.x, diterapkan di wizard LiveView
`/submission/:id/wizard/contributors` dan tab **Contributors** `/submission/wizard/:id?tab=contributors`.

### Fitur
- Klik **Edit** pada baris contributor membuka form edit berisi: **Given Name \***,
  **Family Name**, **Preferred Public Name** (dengan keterangan), **Email \***,
  **Country**, **Homepage URL**, **Bio Statement** (textarea), **Affiliation**,
  **Contributor Role**, dan dua checkbox: **Primary contact** serta **Include in public
  list**.
- Layout form dua kolom: Given/Family Name berdampingan, lalu Preferred Public Name, Email,
  dan Affiliation/Bio Statement selebar penuh; Country dan Homepage URL berdampingan; Role
  berdampingan dengan kolom checkbox.
- Setelah **Save**, kartu kembali ke tampilan daftar baris (sebelumnya form tetap terbuka).
- Field baru dipertahankan di dalam data submission: `preferred_public_name`, `country`,
  `url`, `bio_statement`, `affiliation`, dan `public_list`.

### File yang diubah
- `lib/ojs_landing/submission.ex` — `normalize_contributor_fields/1` menangani field baru
  (preferred_public_name, url, bio_statement, public_list); helper `checkbox_value?` untuk
  nilai checkbox.
- `lib/ojs_landing_web/live/submission_wizard_live.ex` — struct contributor diperluas,
  `build_contributors/2`, `add_contributor`, `apply_contributor_params`,
  `contributors_to_persist`, dan `contributor_edit_form` diupdate; `save_contributor`
  menutup mode edit; template edit form ditulis ulang (10 field).
- `lib/ojs_landing_web/controllers/author_html.ex` — `contributor_form/1` menambah field
  baru.
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — form edit tab
  contributors ditulis ulang dengan field baru; akses field baru memakai `Map.get` agar
  aman untuk data seed lama.
- `assets/css/app.css` — grid form edit dipindah ke `.ojs-contributor-edit-form`;
  gaya baru `.ojs-contributor-edit-options` untuk baris checkbox; responsive 1 kolom di
  layar kecil.
- `test/ojs_landing_web/live/submission_wizard_live_test.exs` — test add/edit diupdate ke
  nama field baru + test edit lengkap dengan asersi semua field tersimpan.
- `test/ojs_landing_web/controllers/author_controller_test.exs` — test edit view mengecek
  field baru; test update mengirim & menegaskan semua field tersimpan.

### Status
- `mix precommit` lulus: 132 test, tanpa warning.

## Contributors: tombol Save Order/Cancel + Edit/Delete yang berfungsi

Langkah **Make a Submission: Contributors** dirapikan di kedua implementasi (wizard LiveView
`/submission/:id/wizard/contributors` dan tab **Contributors** `/submission/wizard/:id?tab=contributors`).

### Fitur
- Klik **Order** pada header card Contributors kini menggantikan tombol Order/Preview/Add
  Contributor dengan tombol **Save Order** dan **Cancel** di sisi kanan header card.
  - Wizard LiveView: handler `toggle_order` menyimpan snapshot urutan saat masuk mode order;
    **Save Order** keluar dari mode order, **Cancel** mengembalikan urutan semula.
  - Tab controller: mode order ditandai `?view=order`; **Save Order**/**Cancel** kembali ke
    tampilan list (`?view` dihapus).
- **Edit** pada baris contributor kini berfungsi: membuka form edit inline di atas daftar
  (`?view=edit&contributor_id=N`) berisi Given name, Family name, Email, Affiliation, Country,
  Role, dan Primary contact dengan tombol **Save** dan **Cancel**.
- **Remove** diganti menjadi **Delete** dan berfungsi: tombol berupa form yang mengirim
  `submission[delete_contributor_id]` (dengan konfirmasi) lalu menghapus kontributor dari daftar.
- Menetapkan **Primary contact** saat mengedit otomatis menghapus penanda Primary dari
  kontributor lain.

### File yang diubah
- `lib/ojs_landing_web/live/submission_wizard_live.ex` — `save_order`/`cancel_order` handler +
  assign `contributor_order_backup`; header actions menampilkan tombol Save Order/Cancel.
- `lib/ojs_landing_web/live/submission_wizard_live.html.heex` — assign `contributor_view`
  diteruskan ke step (konsistensi).
- `lib/ojs_landing/submission.ex` — fungsi baru `update_contributor/3` dan `delete_contributor/3`
  (+ normalisasi field & role).
- `lib/ojs_landing_web/controllers/author_controller.ex` — assign `editing_contributor` di
  `edit_submission`, handler `handle_contributor_edit`/`handle_contributor_delete` di
  `update_submission`.
- `lib/ojs_landing_web/controllers/author_html.ex` — helper baru `contributor_form/1`,
  `contributor_roles/0`, `contributor_role_value/1`, `submission_form_action/4` (dengan opsi
  `contributor_id:`).
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — form edit inline,
  tombol Delete; cabang list kosong yang mati dihapus (perbaikan warning type checker).
- `test/ojs_landing_web/controllers/author_controller_test.exs` — test baru: mode order menampilkan
  Save Order/Cancel, edit view merender form, update contributor, delete contributor.

### Status
- `mix precommit` lulus: 132 test, tanpa warning.

## Contributors: Contributor Card + default author otomatis

Tampilan langkah **Make a Submission: Contributors** dirombak menjadi kartu contributor ala OJS
di kedua implementasi: wizard LiveView `/submission/:id/wizard/contributors` dan tab
**Contributors** pada `/submission/wizard/:id?tab=contributors`.

### Fitur
- Bagian kanan kini berupa **Contributor Card**: panel dengan header yang memuat judul
  **Contributors** di kiri serta tombol **Order**, **Preview**, dan **Add Contributor** di kanan.
- Konten card berupa daftar baris contributor: nama/username pengguna di kiri dengan label peran
  **Author** di sampingnya, lalu di kanan terdapat **Primary Contact**, **Edit**, dan **Remove**.
- **Primary Contact** ditampilkan sebagai badge biru untuk contributor utama; untuk contributor
  lain tampil sebagai tombol untuk menetapkannya sebagai kontak utama.
- **Default author otomatis**: submission baru yang belum memiliki contributor kini otomatis
  menampilkan pengguna yang sedang login sebagai penulis pertama (sebelumnya daftar kosong /
  "Belum ada kontributor terdaftar"). Berlaku di wizard LiveView (fallback `build_contributors`)
  dan di tab controller (helper `display_contributors/2`).
- **Order** menampilkan baris dengan nomor urut + tombol naik/turun; **Preview** menampilkan
  nama, email, peran, dan penanda Primary Contact.
  - Wizard LiveView: Order/Preview memakai handler `toggle_order`/`toggle_preview` yang sudah
    ada dan kini benar-benar mengubah tampilan (`contributor_view` diteruskan ke step).
  - Tab controller: Order/Preview beralih via query param `?view=order` / `?view=preview` yang
    dibaca controller.
- Tombol **Add Contributor** pada tab controller kini menyisipkan kartu dengan markup baris baru
  (sebelumnya markup kartu lama dengan avatar) dan menghapus pesan kosong bila ada.

### File yang diubah
- `lib/ojs_landing_web/live/submission_wizard_live.ex` — `contributors_step` ditulis ulang
  menjadi Contributor Card; `case @contributor_view` untuk tampilan list/order/preview.
- `lib/ojs_landing_web/live/submission_wizard_live.html.heex` — assign `contributor_view`
  diteruskan ke `contributors_step`.
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — tab contributors
  ditulis ulang (panel + baris + view order/preview); JS `#btn-add-contributor` memakai markup
  baru.
- `lib/ojs_landing_web/controllers/author_controller.ex` — `contributor_view` dibaca dari
  `?view=` (order/preview/list).
- `lib/ojs_landing_web/controllers/author_html.ex` — helper baru `display_contributors/2`,
  `default_contributor/1`, `contributor_role_label/1`, `submission_form_action/3` (dengan opsi
  `view:`).
- `assets/css/app.css` — gaya baru `.ojs-contributor-panel*`, `.ojs-contributor-row`,
  `.ojs-contributor-role`, `.ojs-contributor-actions-row`, `.ojs-primary-contact-btn`,
  `.ojs-remove-link`, `.ojs-order-index`, `.ojs-preview-index`.

### Status
- `mix precommit` lulus: 127 test, tanpa warning (dijalankan di WSL agar konsisten dengan
  `_build` server).

## Upload Files: pilihan genre lengkap (9 tipe) ala OJS 3.5

Pada tahap **Upload Files** (wizard LiveView `/submission/:id/wizard/files` dan tab **Upload
Files** `/submission/wizard/:id?tab=files`), pemilihan jenis file ditingkatkan menjadi dua
tingkat ala OJS 3.5.

### Fitur
- File baru / file tanpa genre menampilkan prompt **"What kind of file is this?"** dengan dua
  tombol cepat: **Article Text** dan **Other**.
- Klik **Other** membuka daftar genre lengkap dengan teks **"Choose the option that best
  describes this file"** dan 9 pilihan: Article Text, Research Instrument, Research Materials,
  Research Results, Transcripts, Data Analysis, Data Set, Source Texts, dan Other.
- Klik **Edit** pada file yang sudah ber-genre membuka daftar genre yang sama (genre saat ini
  ditandai) agar bisa diubah; tombol **Cancel** membatalkan tanpa mengubah genre.
- Memilih salah satu genre menutup daftar dan menampilkan chip genre.

### File yang diubah
- `lib/ojs_landing_web/live/submission_wizard_live.ex` — state `genre_picker` per file, handler
  `open_genre_picker`/`close_genre_picker`, daftar `@genres`, template prompt dua tingkat.
- `lib/ojs_landing_web/live/submission_wizard_live.html.heex` — assign `genres` diteruskan ke
  `files_step`.
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — JS: builder
  `buildGenrePicker/1` dan handler `data-genre` untuk tombol Other/Edit/Cancel.
- `assets/css/app.css` — gaya `.ojs-file-genre-picker`, `.ojs-genre-desc`,
  `.ojs-genre-option-selected`.
- `test/ojs_landing_web/live/submission_wizard_live_test.exs` — test: Other membuka daftar
  lengkap, pilih genre dari daftar, Edit membuka picker, Cancel mempertahankan genre.

### Status
- `mix precommit` lulus: 127 test, tanpa warning.

## Upload Files: deskripsi kiri baru + File Upload Section (Files / Add File)

Halaman **Upload Files** dirombak menjadi gaya OJS di kedua implementasi (wizard LiveView
`/submission/:id/wizard/files` dan tab **Upload Files** pada `/submission/wizard/:id?tab=files`).

### Fitur
- Deskripsi di kolom kiri (di bawah judul **Upload Files**) diganti menjadi: "Provide any files
  our editorial team may need to evaluate your submission. In addition to the main work, you may
  wish to submit data sets, conflict of interest statements, or other supplementary files if
  these will be helpful for our editor."
- Kolom kanan kini berupa kartu **File Upload Section** dengan header yang memuat judul **Files**
  di kiri dan tombol **Add File** di kanan.
- Di tengah section terdapat instruksi: "Upload any files the editorial team will need to
  evaluate your submission." dengan tautan **Upload File** yang berwarna biru.
- Klik pada area dropzone, tautan **Upload File**, atau tombol **Add File** membuka dialog
  pemilih file.

### File yang diubah
- `lib/ojs_landing_web/live/submission_wizard_live.ex` — teks aside `files_step` diganti;
  dropzone dibungkus `.ojs-file-upload-section` + header "Files"/"Add File" + teks dropzone baru.
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — tab files diberi
  struktur File Upload Section yang sama (header Files/Add File, deskripsi + Upload File biru).
- `assets/css/app.css` — gaya baru `.ojs-file-upload-section`, `.ojs-file-upload-header`,
  `.ojs-add-file-btn`, `.ojs-file-upload-body`, `.ojs-upload-file-link`.
- `assets/js/app.js` — handler klik global untuk membuka pemilih file dari dropzone, tautan
  **Upload File**, dan tombol **Add File**.

### Status
- `mix precommit` lulus: 125 test, tanpa warning.
- Catatan: build `_build` dikompilasi ulang di WSL (Elixir 1.18.3) agar konsisten dengan server
  yang berjalan; jangan mencampur `mix` antara WSL dan Windows karena berbagi `_build`.

## Upload Files: daftar file bergaya OJS (Edit/Remove + pilihan jenis file)

Tampilan daftar file di tahap **Upload Files** diubah dari tabel menjadi daftar kartu ala OJS:
setiap file yang sudah diunggah menampilkan **nama file** dengan tombol **Edit** dan **Remove**
di sebelah kanannya. Di bawah file yang belum memiliki genre muncul teks **"What kind of file is
this?"** beserta dua tombol pilihan jenis file: **Article Text** dan **Other**. Diterapkan di
keduanya halaman upload: wizard LiveView `/submission/:id/wizard/files` dan tab **Upload Files**
pada `/submission/wizard/:id`.

### Fitur
- Tiap file ditampilkan sebagai kartu: nama file + **Edit**/**Remove** di kanan, lalu baris meta
  (ukuran · tanggal), lalu blok pilihan genre.
- File tanpa genre (baru diunggah / setelah klik **Edit**) menampilkan prompt
  **"What kind of file is this?"** dengan opsi **Article Text** dan **Other**.
- Memilih salah satu opsi menyimpan genre dan menampilkan chip genre (mis. **Article Text**,
  **Other**, atau genre lama seperti *Manuscript*); **Edit** membuka kembali prompt; **Remove**
  menghapus file dari daftar.
- Di halaman edit submission, seluruh JS upload (pilih file, drag & drop, Load Sample File)
  dirombak memakai markup kartu yang sama; pemilihan genre/Edit/Remove memakai event delegation.

### File yang diubah
- `lib/ojs_landing_web/live/submission_wizard_live.ex` — `files_step` ditulis ulang (kartu file
  + prompt genre), `file_entry_result/2` membaca data dari `entry` dan menambahkan `id`
  (perbaikan crash saat upload), `file_genre_label/1` kini menghasilkan "Article Text".
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — tab files diubah
  dari tabel ke daftar kartu; JS upload (getFileSection, updateFileCount, buildFileItem,
  addUploadedFile, addDemoFile) + handler delegasi untuk genre/Edit/Remove.
- `assets/css/app.css` — gaya baru `.ojs-file-item*`, `.ojs-file-genre-prompt`,
  `.ojs-genre-option`, `.ojs-genre-chip`, dst.; `.ojs-danger-icon` dihapus.
- `test/ojs_landing_web/live/submission_wizard_live_test.exs` — test baru: Edit/Remove tampil,
- Remove menghapus file, upload memunculkan prompt genre, pemilihan Article Text/Other,
- Edit membuka kembali prompt.
- `test/ojs_landing_web/controllers/author_controller_test.exs` — test tab files: Edit/Remove +
  prompt genre dirender untuk file tanpa genre.

### Status
- `mix precommit` lulus: 125 test, tanpa warning.

## Wizard Upload Files: unggah file milik user sendiri

Pada tab **Upload Files** di wizard submission controller (`/submission/wizard/:id?tab=files`),
tombol **Upload File** kini membuka dialog pemilih file sungguhan (via `<input type="file">`)
dan menampilkan file asli pilihan user di tabel "Uploaded files". Sebelumnya tombol tersebut
otomatis men-generate file contoh (`manuscript.docx`, `figures.zip`) tanpa meminta input user.

### Fitur
- Tombol **Upload File** → membuka file picker (PDF, DOCX, DOC, ODT, TXT, multiple).
- File yang dipilih ditambahkan ke tabel Uploaded files dengan nama, ukuran, dan tanggal asli.
- **Drag & drop** file ke dropzone kini benar-benar memproses file yang dijatuhkan (sebelumnya
  hanya efek visual).
- Tombol **Load Sample File** tetap tersedia sebagai opsi demo (file contoh, diberi label jelas).

### File yang diubah
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — tambah hidden
  `<input type="file">`, handler `change` untuk file asli, dan handler `drop` nyata; handler
  `#btn-pick-file` tidak lagi memanggil `addDemoFile`.

### Status
- `mix test test/ojs_landing_web/controllers/author_controller_test.exs` lulus: 16 test.

## Form Submission: field Subtitle dihapus, tombol footer rata kanan

### Fitur
- Field **Subtitle** dihapus dari tab Details pada halaman submission
  (`/submission/wizard/:id`), sehingga isian detail kini hanya **Title \***, **Keywords**,
  **Abstract \***, dan **References**.
- Grup tombol footer (**Last saved …**, **Cancel**, **Save for Later**, dan **Continue**)
  dipindahkan ke posisi **rata kanan** pada semua langkah (details, files, contributors,
  editors, review) via `margin-left: auto` pada `.ojs-details-actions`. Tombol **Back** tetap
  di kiri pada langkah selain Details.

### File yang diubah
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — blok field
  Subtitle dihapus.
- `assets/css/app.css` — `margin-left: auto` pada `.ojs-details-actions` untuk footer
  rata kanan.

### Status
- `mix precommit` lulus: 118 test, tanpa warning.

## Wizard Submission: halaman `/submission/wizard/:id` diubah ke gaya OJS 3.5 PKP

Halaman `edit_submission` (setelah membuat submission, diakses di `/submission/wizard/:id`)
diubah dari layout sidebar + tab menjadi **form wizard 5 langkah** bergaya OJS 3.5 PKP,
konsisten dengan halaman `/submission/:id/details` dan wizard LiveView.

### Fitur
- Header hanya berisi judul langkah **Make a Submission: Details** (dst.) di atas **stepper**
  horizontal 5 langkah: **1 Details → 2 Upload Files → 3 Contributors → 4 For the Editor →
  5 Review**. Stepper dapat diklik untuk berpindah langkah; langkah yang sudah selesai
  ditandai **✓ hijau**, langkah aktif biru (tombol "Save for Later" di pojok kanan atas
  dihapus).
- Layout 2 kolom di dalam card putih:
  - Kiri: heading **Submission Details** + teks *"Please provide the following details to help
    us manage your submission in our system."*
  - Kanan: isian **Title \***, **Subtitle**, **Keywords**, **Abstract \*** (rich text editor
    dengan toolbar), dan **References**. Field **Section** dan **Language** dihapus dari
    tampilan.
- Footer card rata kanan berurutan: **Last saved …**, **Cancel**, **Save for Later**, dan
  **Continue** (biru). Step lain memakai pola sama dengan tombol **Back** di kiri dan grup
  tombol (Last saved / Save for Later / Continue / Submit to Journal) di kanan.
- Step **Upload Files**, **Contributors**, **For the Editor**, dan **Review** dirapikan ke
  layout yang sama (aside kiri + konten kanan) tanpa mengubah fungsionalitasnya.

### File yang diubah
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — ditulis ulang ke
  layout wizard (stepper + card 2 kolom + footer), field Section/Language dihapus.
- `lib/ojs_landing_web/controllers/author_html.ex` — helper baru `wizard_step_title/1`,
  `wizard_step_labels/0`, `wizard_step_done?/2`, `wizard_prev_tab/1`.
- `lib/ojs_landing_web/live/submission_wizard_live.html.heex` — tombol "Save for Later" di
  header dihapus (konsistensi).
- `lib/ojs_landing_web/live/submission_wizard_live.ex` — teks aside step Details diperbarui;
  footer semua step dirapikan (Last saved ikut ke grup kanan).
- `lib/ojs_landing_web/controllers/author_html/details.html.heex` — tombol header dihapus,
  teks aside + footer diperbarui sama seperti di atas.
- `assets/css/app.css` — `.ojs-progress-step.is-done`, `.ojs-progress-link`, `margin-left:
  auto` pada `.ojs-details-actions`.
- `test/ojs_landing_web/controllers/author_controller_test.exs` — asersi `wizard-tab-files`
  diganti `step-files` + teks baru.
- `test/ojs_landing_web/live/submission_wizard_live_test.exs` — hapus test tombol header
  `#btn-save-later-top`.

### Status
- `mix precommit` lulus: 118 test, tanpa warning.

## Submission Wizard LiveView (5 langkah)

Wizard "Make a Submission" dibuat ulang sebagai **LiveView** di `/submission/:id/wizard`
(5 langkah: Details, Upload Files, Contributors, For the Editor, Review) menggantikan alur
controller lama. Setiap langkah dirender oleh *step component* tersendiri di dalam
`SubmissionWizardLive`, lengkap dengan progress horizontal, breadcrumb, header dengan tombol
Save for Later, dan halaman **Submission Received** setelah submit.

### Fitur
- **LiveView 5 langkah** (`details`, `files`, `contributors`, `editors`, `review`) dengan
  step components (`details_step`, `files_step`, `contributors_step`, `editors_step`,
  `review_step`) di `lib/ojs_landing_web/live/submission_wizard_live.ex`.
- Route live baru: `live "/submission/:id/wizard"` dan `live "/submission/:id/wizard/:step"`;
  `handle_params` membaca step dari URL, `prev_step/1` & `step_done?/2` untuk navigasi.
- **LiveSocket** di-setup di `assets/js/app.js` (import `phoenix`, `phoenix_live_view`,
  `topbar`, CSRF token, `liveSocket.connect()`).
- Layout khusus `Layouts.submission_live/1`: full-page tanpa header/sidebar, meta csrf,
  link aset, `<.flash_group>`, dan `<main class="ojs-details-page">`.
- **Details**: rich text editor abstract (contenteditable + toolbar, disinkronkan ke
  `<textarea>` tersembunyi), validasi Title & Abstract, tombol Save for Later / Continue.
- **Files**: dropzone `phx-drop-target` + `<.live_file_input>`, progress upload, tabel file
  tersimpan dengan genre (Main text / Other), aksi Remove, limit 10 file / 50 MB.
- **Contributors**: kartu contributor (avatar inisial, edit inline, reorder ↑↓, hapus),
  pemilihan Primary Contact, dan tambah contributor.
- **For the Editor**: textarea komentar untuk editor.
- **Review**: metrik ringkasan (Submission ID, Title, Files, Contributors) + submission
  checklist dinamis + notice original work.
- Submit → halaman **Submission Received** dan status submission menjadi `:active`
  (`Submission.set_status/2`).
- Penyimpanan per-step via `persist_all/1` (title, keywords, abstract, references, files,
  contributors, editor_comments) ke `Submission.update/2`.

### File yang diubah
- `lib/ojs_landing_web/live/submission_wizard_live.ex` (baru) — LiveView + 5 step components
  + helper (normalize_files, build_contributors, validate_details, persist_all, dll).
- `lib/ojs_landing_web/live/submission_wizard_live.html.heex` (baru) — template utama
  (halaman received + kerangka wizard).
- `lib/ojs_landing_web/router.ex` — 2 route live wizard.
- `lib/ojs_landing_web/components/layouts.ex` — komponen layout `submission_live/1`.
- `lib/ojs_landing/submission.ex` — field `editor_comments` + persist `files`/`contributors`
  di `update/2`.
- `assets/js/app.js` — import & setup LiveSocket.
- `assets/css/app.css` — gaya `.ojs-*` untuk wizard (dropzone, tabel file, contributor,
  review, received page, progress).
- `test/ojs_landing_web/live/submission_wizard_live_test.exs` (baru) — 16 test (auth, tiap
  step, validasi, save, contributor, submit).

### Status
- `mix precommit` lulus: 119 test, tanpa warning.

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
