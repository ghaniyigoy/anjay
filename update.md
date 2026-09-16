# Update

Catatan perubahan terbaru pada aplikasi.

## Editorial Dashboard: perbaikan tombol "Assign Reviewers" yang tidak membuka drawer

### Bug
- Tombol **Assign Reviewers** pada kolom **EDITORIAL ACTIVITY** di `/dashboard/editorial` tidak
  berfungsi (klik tidak menampilkan apa-apa).

### Penyebab
- `assets/js/app.js` di-bundle oleh esbuild menjadi IIFE, sehingga fungsi tingkat-atas
  `function arUpdateFilterCount()` tersaring ke dalam scope bundle dan **tidak** terpasang pada
  `window`.
- Skrip inline `editorial.html.heex` (`renderArReviewerCards`) memanggil `arUpdateFilterCount()`,
  yang memicu `ReferenceError: arUpdateFilterCount is not defined` — eksekusi berhenti sebelum
  `overlay.classList.add('ar-open')`, sehingga drawer Add Reviewer tidak pernah terbuka.

### Perbaikan
- `assets/js/app.js` — `arUpdateFilterCount` kini diekspos ke global:
  `window.arUpdateFilterCount = function() {...}` (sejalan dengan helper `ar*` lain yang sudah
  memakai `window.`).
- `mix assets.build` dijalankan ulang agar bundle baru tersaji; pengguna perlu hard-refresh
  (Ctrl+F5).

### Status
- Drawer **Add Reviewer** (slide-in kanan ke kiri) kini terbuka, merender kartu reviewer, dan
  tombol **Select Reviewer** dapat mengirim `POST /dashboard/editorial/:id/assign-reviewer`.

## Editorial Dashboard: "Assign Reviewers" menjadi Add Reviewer Page (slide-in kanan ke kiri)

Tombol **Assign Reviewers** pada kolom **EDITORIAL ACTIVITY** di
`/dashboard/editorial?currentViewId=assigned-to-me` kini membuka **Add Reviewer Page** berupa
drawer yang menyusup dari **kanan ke kiri** (`translateX(100%) → 0`, animasi 0.3s, backdrop gelap)
— menggantikan modal centered lama (`ar-modal-overlay`). Drawer memakai pola slide-in yang sama
dengan Add Reviewer di workflow `workflow_3_1` (`ar-overlay`/`ar-panel`) sehingga tampilannya
konsisten di kedua halaman.

### Tampilan
- **Header** biru `#006798`: tombol **panah kiri** (tutup) + judul terpusat **"Add Reviewer"**
  (spacer di kanan agar judul seimbang).
- Section **Submission Author List**: kotak berisi **avatar inisial + `username - affiliation`**
  (diisi dari submission yang sedang diproses; fallback ke nama author bila username kosong).
- Heading **Locate a Reviewer** di kiri, sejajar di kanan: **Search box** (memfilter langsung saat
  mengetik via `arFilterReviewers()`) + tombol **Filters**.
- **Sidebar Filters** (slide di kiri): opsi bertombol **+** (Rated at least, Reviews completed,
  Days since last review assigned, Active reviews currently assigned, Average days to complete
  review) dengan counter "n filters", tombol **Reset**, dan tombol hapus per filter.
- **Daftar reviewer**: kartu `.ar-reviewer-card` yang di-render **client-side** ke `#ar-reviewer-list`
  dari `window.__arReviewers` (`@ap_users_json`), menampilkan username, affiliation, dan statistik
  Review Count / Last Review / Status. Tombol **Select Reviewer** langsung mensubmit hidden form
  `#assign-reviewer-form` → `POST /dashboard/editorial/:id/assign-reviewer`.
- **Footer**: **Create New Reviewer** dan **Enroll Existing User** (placeholder, alert "coming soon").
- Navigasi tutup: panah kiri, klik backdrop, atau tombol **Escape** (reuse handler global di
  `assets/js/app.js`).

### Data
- `EditorController.editorial/2` (klausa dashboard) kini mengirim `ap_submissions_json` dengan field
  tambahan `username` dan `affiliation` per submission — diambil dari **primary contact contributor**
  (fallback `author_username` / akun user) melalui helper baru `author_username/1` + `author_affiliation/1`.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_controller.ex` — `ap_submissions_json` kini menyertakan
  `username` + `affiliation`; helper baru `author_username/1`, `author_affiliation/1`,
  `account_affiliation/1`.
- `lib/ojs_landing_web/controllers/editor_html/editorial.html.heex` — markup Add Reviewer diganti
  dari centered modal `ar-modal-overlay` menjadi slide-in drawer `ar-overlay`/`ar-panel` (header
  panah kiri, Submission Author List, Locate a Reviewer + Search + Filters, sidebar filters, kartu
  reviewer client-side, footer); JS `openAddReviewerModal`/`renderArReviewerCards`/`selectArReviewer`
  memakai class `ar-open` dan reuses yang global di app.js.

### Status
- `mix precommit` lulus: 159 test, 0 failures.

## Workflow `workflow_3_1` (editor): perbaikan interaksi kartu Files for Review, Participants, Review Discussions, dan modal Add Reviewer

Serangkaian perbaikan pada halaman workflow editor di
`/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_3_1`.

### Upload Review File tidak lagi muncul di belakang dialog Current Review Files
- Saat tombol **Upload Review Files** diklik dari dialog **Current Review Files For Round 1**
  (dibuka lewat **Upload/Select Files** pada kartu **Files for Review**), modal upload kini tampil
  di depan. Penyebabnya `.ufr-overlay`/`.urf-overlay` ber-`z-index: 10000`, lebih rendah dari
  `.rfs-overlay` (10010), sehingga modal upload tergambar di belakang dialog.
- `assets/css/app.css` — `.urf-overlay` dinaikkan menjadi **`z-index: 10015`** (di atas rfs 10010,
  tetap di bawah overlay lain: ar 10020, apd 10025, prd 10030, udf 10040).

### Tombol Assign pada kartu Participants berfungsi kembali
- Tombol **Assign** di kartu **Participants** (`#btn-assign-participant-review`) sebelumnya tidak
  punya `onclick` sehingga drawer Assign Participant tidak pernah terbuka.
- `workflow.html.heex` — ditambahkan `onclick="openAssignParticipantDrawer()"` (sama dengan tombol
  Assign di `workflow_1`), sehingga membuka drawer `.apd-*` yang sama.

### Tombol Add Discussion pada kartu Review Discussions berfungsi kembali
- Tombol **Add Discussion** di kartu **Review Discussions** (`#btn-add-discussion-review`) tidak
  punya `onclick`, padahal tombol serupa di Pre-Review Discussions sudah memanggil
  `openPreDiscussionModal()`.
- `workflow.html.heex` — ditambahkan `onclick="openPreDiscussionModal()"` untuk membuka modal
  **Add discussion** (`.prd-*`) instance yang sama.

### Modal Add Reviewer: daftar author tanpa dropdown + pemilihan reviewer langsung
- Modal **Add Reviewer** (slide-in `.ar-overlay`) kini menampilkan panel **Submission Author List**
  di bagian atas sebagai daftar statis: avatar inisial + nama + afiliasi setiap kontributor
  submission — **tanpa dropdown** (sebelumnya pemilihan mengandalkan dropdown `(username) - (affiliation)`).
- Pemilihan reviewer diubah dari dropdown (tombol **Select Reviewer** + panah membuka panel
  `ar-select-dropdown` berisi statistik) menjadi **tombol langsung**: klik **Select Reviewer**
  langsung mengirim form assignment (`arSelectReviewer('ar-assign-form-<id>')`). Tombol panah dan
  seluruh markup `.ar-select-dropdown` dihapus.

### File yang diubah
- `assets/css/app.css` — `.urf-overlay` `z-index` 10000 → 10015.
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — `#btn-assign-participant-review`
  + `#btn-add-discussion-review` memakai onclick yang benar; modal Add Reviewer: panel static
  **Submission Author List** + tombol **Select Reviewer** langsung submit assignment.

### Status
- `mix precommit` lulus: 159 test, tanpa warning.

## Editorial Dashboard: "Assign Editor" diubah menjadi Assign Participant Drawer (slide-in kanan)

Tombol **Assign Editor** pada kolom **EDITORIAL ACTIVITY** di `/dashboard/editorial` kini membuka
**Assign Participant page** berupa **drawer yang menyusup dari kanan ke kiri** (`translateX(100%) → 0`,
animasi 0.3s, backdrop gelap) — menggantikan modal lama (`ap-` prefix). Drawer memakai pola slide-in
yang sama dengan drawer Assign Participant di `workflow_1` (prefix `.apd-*`), sehingga tampilan kini
konsisten di kedua halaman.

### Tampilan
- **Header** biru `#006798`: tombol **panah kiri** (tutup) + judul terpusat **"Assign Participant"**
  (spacer di kanan agar judul seimbang).
- Section **Locate a User** (heading besar `.apd-heading`):
  - Dropdown role (`#ap-role-filter`, class `.apd-select`) dengan opsi **Journal Editor**,
    **Section Editor**, **Guest Editor**, **Funding coordinator**, **Author**, **Translator**.
  - Di kanan dropdown, kotak **pencarian** (ikon magnifier + input `#ap-search-name`) yang memfilter
    tabel langsung saat mengetik (`oninput="filterAssignEditorUsers()"`).
- Heading **Search User By Name** (`.apd-search-heading`, label uppercase di bawah baris Locate a User).
- **Tabel user** (`#ap-users-table`, header **Name | Assignments | Affiliation | Reviewing Interest**)
  di-render client-side ke `#ap-users-tbody` dari `window.__apUsers` (`@ap_users_json`); kolom
  Assignments = `reviews_completed`, Reviewing Interest = `reviewing_interests`. Baris terpilih
  ter-highlight `.apd-user-selected`; empty-state **"No users found."** (`#ap-no-results`).
- **Bagian Message**: instruksi "Choose a predefined message to use, or fill out the form below." +
  dropdown **Predefined Message** (Discussion (Submission) / Assign Editor) + editor rich-text
  (B/I/U/Bullet via `execCommand`), toolbar tetap memakai class `ap-richtext-*`.
- **Footer**: **Cancel** (tutup drawer) + **Send** (submit hidden form `#assign-editor-form` →
  `POST /dashboard/editorial/assign-editor`; alert "Please select a user first." bila belum ada user
  terpilih).
- Navigasi tutup: panah kiri, Cancel, klik backdrop, atau **Escape**.
- `openAssignEditorModal(submissionId)` kini men-toggle class **`apd-open`** pada `#assign-editor-overlay`
  (bukan `style.display`), dan user filter/select memakai class `.apd-user-row` / `.apd-user-selected`.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/editorial.html.heex` — markup modal lama diganti
  drawer `.apd-*` (overlay `#assign-editor-overlay`, panel, header, locate row, heading
  "Search User By Name", tabel `#ap-users-table`, message section, footer Cancel/Send); JS
  open/close memakai toggle class `apd-open`; `filterAssignEditorUsers()` memperbarui class baris
  menjadi `apd-user-row`/`apd-user-selected` dan kolom Assignments/Reviewing Interest dari
  `u.reviews_completed`/`u.reviewing_interests`. Hidden form `#assign-editor-form` tidak berubah.
- `assets/css/app.css` — tambah class **`.apd-search-heading`** (label "Search User By Name").
- `AGENTS.md` — deskripsi "Assign Editor modal" diperbarui menjadi "Assign Editor drawer".

## Workflow `workflow_1` (editor): drawer "Assign Participant" di-redesign dengan tabel user + bagian Message + tombol Cancel/OK

Pada halaman workflow editor (`/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_1`),
tombol **Assign** pada kartu **Participants** (`wf-col-side`) membuka **Assign Participant drawer** —
panel ala OJS 3.5 yang muncul menyusup dari **kanan ke kiri** (`translateX(100%) → 0`, animasi 0.3s,
backdrop gelap), memakai pola slide-in yang sama dengan modal Add Reviewer / Upload Review File
(`.ar-overlay`, `.urf-overlay`). Drawer kini di-redesign mengikuti pola modal **Assign Editor** di
dashboard (`ap-` prefix): daftar user berupa **tabel**, lengkap dengan bagian **Message** (predefined
message + editor rich-text) dan tombol aksi **Cancel / OK**.

### Fitur
- **Header** biru `#006798` dengan tombol **panah kiri** (tutup) di kiri dan judul
  **"Assign Participant"** di tengah (spacer di kanan agar judul terpusat). Panel drawer diubah
  dari `520px` menjadi **`720px`** agar tabel nyaman dibaca.
- Section **Locate a User**:
  - Dropdown role (`#apd-role-filter`) dengan opsi **Journal Editor**, **Section Editor**,
    **Guest Editor**, **Finding coordinator**, **Author**, **Translator**.
  - Di kanan dropdown, kotak **pencarian** (ikon magnifier + input `#apd-search-name`) yang
    memfilter tabel langsung saat mengetik (`oninput="apdFilterUsers()"`).
- **Tabel user di tengah** (`#apd-users-table`) dengan header
  **Name | Assignments | Affiliation | Reviewing Interest**:
  - Baris di-render client-side ke `#apd-users-tbody` dari `window.__apUsers` (semua user
    `OjsLanding.User.all()` lewat `reviewer_json/1`, dikirim dari controller sebagai JSON).
  - Kolom Name menampilkan nama (given+family fallback username) + email di bawahnya; Assignments =
    `reviews_completed`; Affiliation = `affiliation`; Reviewing Interest = `reviewing_interests`.
  - **Pilih user** → baris ter-highlight `.apd-user-selected` (background `#e4f0f8` + garis kiri
    biru `#006798`); pilihan tersimpan ke hidden form.
  - **Filter client-side** `apdFilterUsers()`: role dari dropdown + pencarian nama/email.
    Empty-state **"No users found."** (`#apd-no-results`) bila tidak ada yang cocok.
- **Bagian Message** di bawah tabel:
  - Instruksi: **"Choose a predefined message to use, or fill out the form below."**
    (`.apd-message-hint`, italic abu).
  - Label **Predefined Message** + dropdown `#apd-predefined-message` dengan opsi
    **Discussion (Submission)** dan **Assign Editor** — memilih salah satu mengisi editor
    message otomatis via `apdApplyPredefinedMessage(this.value)`.
  - Label **Message** + editor rich-text (`.apd-richtext-wrapper`): toolbar B/I/U/Bullet
    (`.apd-richtext-btn`, `data-cmd`, `execCommand`) + div contenteditable `#apd-message-editor`
    (placeholder "Type your message here..." saat kosong).
- **Footer kanan bawah**: tombol **Cancel** (menutup drawer) dan **OK** (mensubmit hidden form
  `#assign-participant-form` → `POST /dashboard/editorial/assign-editor`; isi editor message
  disalin ke hidden `name="message"`; alert "Please select a user first." bila belum ada user
  terpilih).
- Setelah assign, `EditorController.assign_editor/2` **kembali ke workflow yang sama**: bila hidden
  `workflowMenuKey` dikirim, redirect ke `workflow_menu_path(submission_id, view, menu)` via helper
  `assign_editor_redirect/3`.
- Navigasi tutup: panah kiri, Cancel, klik backdrop, atau tombol **Escape**.
- Style prefiks `apd-` (overlay `justify-content: flex-end`, panel `translateX(100%)` lebar `720px`,
  header, locate row, search box, tabel user + row selected, message section + richtext, footer,
  tombol `.apd-btn-cancel`/`.apd-btn-ok`; responsif `< 600px` panel full-width, dropdown turun ke
  atas search).

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_controller.ex` — render workflow menambahkan assign
  `ap_users_json` (JSON string via `Jason.encode!` dari `reviewer_json/1`, dipakai JS drawer).
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — markup drawer
  `#assign-participant-drawer` (`.apd-*`) di-redesign: script `window.__apUsers`, tabel
  `#apd-users-table` + tbody kosong, bagian Message (hint + predefined dropdown + richtext editor),
  footer **Cancel / OK**. Hidden form `#assign-participant-form` ditambah input `name="message"`.
  Tombol Assign `#btn-assign-participant` tetap memanggil `openAssignParticipantDrawer()`.
- `assets/js/app.js` — rewrite fungsi `apd-*`: `apdReset` (reset filter + message),
  `apdFilterUsers` (render tabel client-side), `apdSelectUser`, `apdApplyPredefinedMessage`,
  `apdSubmit` (salin message + submit), `apdEscapeHtml`, init toolbar `.apd-richtext-btn`, handler
  klik backdrop & Escape.
- `assets/css/app.css` — section `.apd-*` diperbarui: panel `720px`, tabel
  `.apd-users-table`/`.apd-user-row`/`.apd-user-selected`, message section
  (`.apd-message-hint`, `.apd-message-label`, `.apd-predefined-select`, `.apd-richtext-*`),
  tombol `.apd-btn-ok` (menggantikan `.apd-btn-send`); style kartu lama (`.apd-user-card`,
  `.apd-user-avatar`, dsb.) dihapus.

### Status
- `mix precommit` lulus: 159 test, 0 failures.
- `mix assets.build` sukses (perlu hard-refresh browser Ctrl+F5).
- Terverifikasi live: markup drawer ter-render (tabel + message section + tombol OK), `window.__apUsers`
  berisi semua user dengan `role`/affiliation/interests, JS `apdFilterUsers`/`apdApplyPredefinedMessage`
  ada di bundle, CSS `.apd-users-table`/`.apd-richtext-editor`/`.apd-btn-ok` tersaji.

## Comment for the Editor (`workflow_1` author): tombol Edit dihapus + Add Message menyimpan balasan ke thread

Pada detail panel **Comment for the Editor** (`/submission/:id/workflow?workflowMenuKey=workflow_1`,
dibuka dari baris "Comments for The editor" di kartu Pre-Review Discussions), tampilan dan perilaku
diubah sesuai permintaan:

### Fitur
- **Tombol Edit dihapus** dari section **Participants** (sebelumnya ada tombol text biru "Edit" di
  kanan header). Header Participants kini hanya berisi judul.
- **Add Message** (sebelumnya tombol tanpa aksi) kini men-toggle area balasan `#pcd-reply-section`
  (tersembunyi saat awal):
  - Heading **"Message"** + editor rich-text (`.prd-richtext`, toolbar B/I/U/Bullet/Link,
    `data-target="pcd-message"`, disinkronkan ke hidden input `name="message"` via
    `initRichtextEditors()`).
  - Kotak **Attached Files** di bawah editor: judul di kiri, tombol **Search** + **Upload File**
    sejajar di kanan (reuse `.prd-attach-*`).
  - Footer kanan-bawah: tombol **Cancel** (menutup area balasan, `togglePcdReplySection()`) dan
    **OK** (`type="submit"`).
- **OK** mensubmit form `#pcd-reply-form` → route baru **`POST /submission/:id/workflow/editor-reply`**
  (`AuthorController.add_editor_reply/2`, CSRF + `workflowMenuKey` tersembunyi). Pesan kosong
  (setelah strip HTML) ditolak dengan flash error; balasan disimpan ke `submission.editor_replies`
  (map `%{author, message, date}`, tanggal berformat `YYYY-MM-DD HH:MM` UTC saat ini), lalu redirect
  balik ke workflow yang sama.
- **Tabel Pre-Review Discussions** baris "Comments for The editor" kini menampilkan:
  - **From**: username (`author_username`) dengan tanggal `YYYY-MM-DD HH:MM` di bawahnya
    (helper `EditorHTML.editor_comment_from/1`, ambil `date_submitted` fallback `created_at`).
  - **Last Reply**: username + tanggal balasan terakhir bila sudah ada balasan (`List.last` dari
    `editor_comment_replies/1`), selain itu "—".
  - **Replies**: jumlah balasan. Sel dua baris diberi kelas `.ec-thread-name` (bold) +
    `.ec-thread-date` (abu kecil).
- **Panel Comment for the Editor**: setiap balasan ditampilkan sebagai kotak `.pcd-note-box-reply`
  di bawah note asli, dengan heading author ("From:" style) + tanggal dan isi pesan (rendered `raw`).
- `editor_comments_present?/1` kini juga bernilai true bila `editor_replies` tidak kosong, sehingga
  baris thread tetap tampil meski author belum mengisi komentar awal.

### File yang diubah
- `lib/ojs_landing/submission.ex` — field `editor_replies` (default `[]`), fungsi
  `add_editor_reply/3`.
- `lib/ojs_landing_web/router.ex` — route `post "/submission/:id/workflow/editor-reply"`.
- `lib/ojs_landing_web/controllers/author_controller.ex` — aksi `add_editor_reply/2` (guard login/
  submission kosong, validasi pesan, simpan + flash).
- `lib/ojs_landing_web/controllers/editor_html.ex` — helper `editor_comment_replies/1`,
  `editor_comment_last_reply/1`, `editor_comment_from/1`, `format_dt/1`; perluasan
  `editor_comments_present?/1`.
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — hapus tombol Edit; area
  balasan `#pcd-reply-section` (form, rich-text Message, Attached Files, footer Cancel/OK); render
  balasan di panel; sel From/Last Reply dua baris di tabel.
- `assets/js/app.js` — `togglePcdReplySection/3` (toggle + fokus editor) dipakai tombol Add Message
  dan Cancel.
- `assets/css/app.css` — `.ec-thread-name`, `.ec-thread-date`, `.pcd-note-box-reply`.

### Status
- `mix compile` bersih; `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).
- `mix precommit` lulus: 159 test, 0 failures.
- Data balasan tersimpan di Agent store in-memory (hilang saat server restart).

## Pre-Review Discussions (`workflow_1` author): tombol "Add Discussion" aktif + peringatan inline saat belum ada editor

Pada workflow read-only author (`/submission/:id/workflow?workflowMenuKey=workflow_1`),
tombol **Add Discussion** di kartu **Pre-Review Discussions** sebelumnya **dinonaktifkan**
(`disabled` + pesan "No other participants are available yet") selama submission belum punya
editor. Sekarang tombol **selalu aktif** dan membuka modal, sesuai permintaan pengguna;

### Fitur
- Tombol **Add Discussion** (`#btn-add-discussion-pre`) selalu dapat diklik dan membuka modal
  `#pre-discussion-overlay` (handler `openPreDiscussionModal()` kembali normal).
- Saat **author** meng-submit diskusi padahal submission **belum punya editor** (hanya author
  sebagai satu-satunya partisipan), muncul **peringatan merah inline di dalam modal** — bukan
  redirect flash — dengan teks:
  **"Belum ada editor yang ditugaskan, sehingga diskusi belum dapat dimulai."**
  (`.prd-error`, id `#prd-self-only-error`, border kiri merah `#c5221f`, background `#fce8e6`).
  Isian yang sudah diketik di modal tidak hilang; peringatan hilang setelah pengguna mengetik
  lagi di form.
- Deteksi partisipan via atribut `data-self-only="true"|"false"` pada form `#pre-discussion-form`
  (bernilai string eksplisit karena HEEx merender boolean `true` sebagai attribute bare dan
  meng-omit bila `false`):
  - `"true"` saat `@mode == :author` dan `other_discussion_participants(@submission) == []`
    (helper `EditorHTML.other_discussion_participants/1` mengembalikan `submission.editors || []`).
  - `"false"` atau hilang → tidak self-only, tombol tetap mengirim form.
- **Server-side guard tetap ada sebagai pengaman**: `AuthorController.add_discussion/2`
  (line ~258) menolak POST `/submission/:id/discussion` dengan flash error yang sama bila
  belum ada editor. Jalur editor (`EditorController.add_discussion/2`) tidak terpengaruh.

### Catatan implementasi (HEEx)
- Boolean `true/false` pada atribut HEEx dirender sebagai attribute **bare**/di-omit — bukan
  `"true"`/`"false"`. Karena JS membaca `getAttribute(...) === 'true'`, nilai atribut dibuat
  string eksplisit dengan `if ..., do: "true", else: "false"`.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — kartu Pre-Review
  Discussions: tombol selalu aktif (onclick `openPreDiscussionModal()`); form
  `#pre-discussion-form` diberi `data-self-only`; div `#prd-self-only-error` (`.prd-error`)
  di dalam modal setelah section Participants.
- `assets/js/app.js` — handler submit `#pre-discussion-form`: bila
  `data-self-only == "true"` → `preventDefault()` + tampilkan `#prd-self-only-error`; error
  disembunyikan kembali saat pengguna mengetik (event `input`).
- `assets/css/app.css` — rule baru `.prd-error` (margin/padding, border kiri 4px merah,
  background, warna teks, radius 3px).
- `lib/ojs_landing_web/controllers/editor_html.ex` — helper `other_discussion_participants/1`
  (ditambahkan pada iterasi sebelumnya, dipakai atribut + guard).
- `lib/ojs_landing_web/controllers/author_controller.ex` — guard `add_discussion/2`
  (ditambahkan pada iterasi sebelumnya, tetap dipertahankan sebagai pengaman).
- `assets/css/app.css` — class `.wf-btn-link.wf-btn-disabled` (iterasi lama) **dihapus** karena
  sudah tidak terpakai.
- `test/ojs_landing_web/controllers/author_controller_test.exs` — describe "author workflow
  discussions" disesuaikan: tombol aktif + `data-self-only="true"` + elemen error ada saat
  tanpa editor; `data-self-only="false"` saat editor ditugaskan; POST tanpa editor tetap
  ditolak server.

### Status
- `mix precommit` lulus: 159 test, 0 failures.
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).
- Terverifikasi live pada `/submission/15/workflow?workflowMenuKey=workflow_1` (login author):
  `btn-add-discussion-pre` aktif, `data-self-only="true"` dan `#prd-self-only-error` dirender;
  handler JS `prd-self-only-error` ada di bundle asset.

## Pre-Review Discussions (`workflow_1`): baris "Comments for The editor" membuka detail panel (drawer kanan→kiri)

Pada tabel **Pre-Review Discussions** (`workflow_1`), nama baris **"Comments for The editor"**
(previously teks polos) kini berupa **link biru** yang dapat diklik dan membuka **Comment for the
Editor detail panel** — drawer ala OJS 3.5 yang menyusup dari **kanan ke kiri** (`translateX(100%) → 0`,
animasi 0.3s, backdrop gelap) — memakai pola slide-in yang sama dengan modal Pre-Review/Upload
Discussion File (`.prd-overlay`/`.prd-panel`).

### Fitur
- Baris Name (hanya tampil bila `editor_comments_present?(submission)` true) dirender sebagai link
  `#link-open-editor-comment` ber-class `.wf-discussion-link` (biru `#006798`, hover underline), dan
  meng-call `openEditorCommentPanel()`.
- Panel `#editor-comment-overlay` berisi:
  - **Header** biru `#006798`: tombol **panah kiri** (tutup) di kiri + judul **"Comment for the
    Editor"** (spacer di kanan agar judul terpusat).
  - Section **Participants**: judul + tombol **Edit** di kanan, baris avatar (inisial) + nama
    penulis + role "Author".
  - Section **Message**: kotak `.pcd-note-box` dengan kepala **Note** (kiri) + **From: <nama>**
    (kanan), dan isi note dari field `editor_comments` (fallback `comments_to_editor`) yang di-render
    `raw` (rich text).
  - Tombol **Add Message** (outline biru, ikon `+`) di bagian bawah.
- Nama peserta/From diambil dari **primary contributor** (fallback `author_username`); inisial avatar
  via `contributor_initials` (fallback "A").
- Tutup panel: panah kiri, klik backdrop, atau tombol Escape (handler JS terpisah dari modal
  Pre-Review sehingga tidak bentrok).

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — baris "Comments for The editor"
  jadi link (`onclick="openEditorCommentPanel()"`); markup drawer `#editor-comment-overlay`
  (header, Participants, Message, tombol Add Message).
- `lib/ojs_landing_web/controllers/editor_html.ex` — helper `pcd_initials/1`,
  `pcd_participant_name/1`, `pcd_editor_comment/1` (+ private `pcd_primary_contributor/1`).
- `assets/js/app.js` — `openEditorCommentPanel/closeEditorCommentPanel`, klik backdrop & Escape
  untuk menutup.
- `assets/css/app.css` — section `.pcd-*` + `.wf-discussion-link`.

### Status
- `mix compile --warnings-as-errors` bersih; `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).
- Terverifikasi: link, panel, nama peserta, isi note rich-text, dan tombol Add Message render di
  halaman (`/submission/:id/workflow?workflowMenuKey=workflow_1`).

## Pre-Review Discussions (`workflow_1`): Upload Discussion File Modal (drawer kanan→kiri) + Attach to Discussion

Pada modal **Add Discussion** kartu **Pre-Review Discussions** (`workflow_1`), tombol **Upload File**
(`#prd-btn-upload-file`) kini membuka **Upload Discussion File Modal** — drawer ala OJS 3.5 yang
muncul menyusup dari **kanan ke kiri** (`translateX(100%) → 0`, animasi 0.3s, backdrop gelap).

### Fitur
- **Header** biru `#006798`: tombol **panah kiri** (tutup) di kiri + judul **"Upload a Discussion File"**
  di tengah (spacer di kanan agar judul terpusat).
- **Stepper 3 langkah**: **1. Upload File** · **2. Review Details** · **3. Confirm** (nomor lingkaran +
  connector, aktif biru `#006798`, selesai hijau `#2e7d32`). Step dapat diklik (`udfGoToStep`) untuk
  langkah yang sudah dicapai.
- **Step 1 — Upload File**: field wajib **Article Component** (`*` merah `.udf-required`) dengan
  dropdown "Select article component" dan opsi Article Text, Research Instrument, Research Materials,
  Research Results, Transcript, Data Analysis, Data Set, Source Text, Other. Setelah memilih komponen,
  tombol **Upload File** muncul; setelah file dipilih tampil nama + ukuran file dan tombol berubah
  menjadi **Change file**.
- **Step 2 — Review Details**: label **"Name the file (e.g., Manuscript; Table 1)"** dengan `*` merah
  + kolom input yang **otomatis terisi nama file** dari Step 1 (tanpa ekstensi), tetap bisa diedit.
  Continue aktif hanya bila nama tidak kosong (`updateUdfNameDetail`).
- **Step 3 — Confirm**: teks **"File Added"** + tombol **Attach to Discussion** (ikon paperclip).
- Footer aksi rata kiri: **Cancel** dan **Continue** (label berubah: Continue → Continue →
  "Attach to Discussion"); Continue nonaktif di Step 1 sampai komponen + file terisi.
- **Attach to Discussion**: menyimpan file ke daftar `.prd-attach-body` pada modal Add Discussion
  sebagai baris `.prd-attach-file-row` ber-chip `.prd-attach-file-chip` (komponen — nama), dan mengisi
  hidden input `#prd-attached-files` (JSON). Menutup drawer kanan→kiri kembali.
- Navigasi tutup: panah kiri, Cancel, klik backdrop, atau tombol Escape.
- Style dengan prefiks `udf-` di `assets/css/app.css` (overlay `justify-content: flex-end`, modal
  `translateX(100%)`, shadow kiri `-8px 0 30px`, header, stepper, field, footer).

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — tombol `#prd-btn-upload-file`
  memanggil `openUploadDiscussionFileModal()`; markup drawer `#upload-discussion-file-overlay`
  (header, stepper 3 step, field Article Component, input nama file, footer).
- `assets/js/app.js` — `openUploadDiscussionFileModal/closeUploadDiscussionFileModal`, `resetUdf`,
  `onUdfArticleComponentChange`, `onUdfFileSelected`, `formatUdfBytes`, `updateUdfContinue`,
  `showUdfStep`, `udfGoToStep`, `udfNextStep` (pengisian otomatis nama file), `getUdfFileName`,
  `updateUdfNameDetail`, `udfAttachFile` (tulis ke `.prd-attach-body` + hidden input), klik backdrop
  & Escape.
- `assets/css/app.css` — section `.udf-*` (overlay drawer kanan, modal slide, header, stepper, field,
  input, footer) + `.prd-attach-file-row` & `.prd-attach-file-chip`.

### Status
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).
- `mix compile --force` bersih.

## Pre-Review Discussions (`workflow_1`): editor rich-text untuk Message + panel Attached Files

Modal **Add Discussion** di kartu **Pre-Review Discussions** (`workflow_1`) kini dilengkapi
komponen pengiriman ala OJS 3.5:

### Fitur
- **Message** sekarang berupa editor rich-text (prefiks CSS `prd-`) menggantikan textarea polos:
  - Toolbar `.prd-toolbar` berisi B (bold) / I (italic) / U (underline) / Bullet List
    (`insertUnorderedList`) / Insert link (`createLink`), tombol dengan `data-cmd` seperti editor
    `rp-`/`enr-` lain.
  - Isi editor disinkronkan ke hidden input `name="message"` (`id=prd-message`) via
    `initRichtextEditors()` (`assets/js/app.js`), sehingga POST ke `/discussion` tetap berjalan.
  - `data-placeholder` "Write your message…" tampil saat kosong.
- **Attached Files**: kotak `.prd-attach-box` di bawah editor Message, berjudul **Attached Files**
  di kiri dan tombol **Search** (`#prd-btn-search-file`) + **Upload File** (`#prd-btn-upload-file`)
  sejajar di kanan. Badan kotak menampilkan empty-state "No files are attached to this
  discussion." Terdapat hidden input `attached_files` (`id=prd-attached-files`).

### Penghapusan dropdown "Choose a predefined message"
- Dropdown `#prd-message-type` ("Discussion (Submission)" / "Assign Editor") beserta hint
  "Choose a predefined message to use, or fill out the form below." dihapus karena hanya relevan
  untuk editor. Fungsi JS `onPreDiscussionTypeChange/1` juga dihapus (sudah tidak terpakai).

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — editor rich-text Message +
  kotak Attached Files; hapus dropdown & hint predefined message.
- `assets/css/app.css` — styles `.prd-toolbar*`, `.prd-richtext*`, `.prd-attach-*`,
  `.prd-btn-outline`.
- `assets/js/app.js` — daftarkan `.prd-richtext[data-target]` di selector
  `initRichtextEditors()`; hapus `onPreDiscussionTypeChange`.

### Verifikasi
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).
- `mix precommit` lulus: 155 test, 0 failures.

## Pre-Review Discussions (`workflow_1`): tombol "Add Discussion" kini berfungsi penuh

Pada halaman workflow (`/dashboard/editorial?workflowSubmissionId=<id>&workflowMenuKey=workflow_1`),
tombol **Add Discussion** di kartu **Pre-Review Discussions** sebelumnya hanya placeholder
(tanpa handler/tujuan). Kini tombol membuka **modal Add Discussion**, dan diskusi yang ditambahkan
disimpan ke submission serta tampil di tabel.

### Fitur
- Tombol **Add Discussion** (`id=btn-add-discussion-pre`, onclick `openPreDiscussionModal()`) di
  header kartu membuka modal `#pre-discussion-overlay` (centered, gaya OJS 3.5, prefiks CSS `prd-`,
  header biru `#006798`).
- Modal berisi form (subject wajib + message wajib) yang **POST** ke route baru
  `POST /dashboard/editorial/:id/discussion` (`EditorController.add_discussion/2`, dengan guard
  editor). CSRF + `currentViewId` + `workflowMenuKey` dikirim sebagai hidden input, sehingga
  redirect kembali ke halaman workflow yang sama.
- Nama author diskusi diambil dari `current_user` (given + family name), fallback "Editor".
- Tabel **Pre-Review Discussions** kini merender kolom `Name | From | Last Reply | Replies | Closed`:
  - Baris **"Comments for The editor"** tetap tampil bila `editor_comments_present?(submission)`
    true (Name = "Comments for The editor", From = `author_username`, kolom lain "—").
  - Setiap diskusi tersimpan ditampilkan sebagai baris (Name = subject, From = author, Last Reply /
    Replies / Closed dari `discussion_last_reply/1`, `discussion_replies_count/1`,
    `discussion_closed_label/1` — helper yang sama dengan Review Discussions).
  - Jika tidak ada komentar maupun diskusi, `.wf-empty` menampilkan "No Items".
- Tutup modal: tombol &times; di header, tombol Cancel, klik backdrop, atau tombol Escape.

### Perbaikan bug: `KeyError key :discussions not found`
- **Gejala:** setelah field `:discussions` ditambahkan di struct, halaman workflow_1 error
  `KeyError key :discussions not found in: %OjsLanding.Submission{...}` karena server dev
  menyimpan struct submission yang dibuat **sebelum** penambahan field (hot-reload tidak
  memigrasi data struct lama di Agent store in-memory).
- **Perbaikan:** akses menjadi defensif — template memakai `Map.get(@submission, :discussions) ||
  []`, dan `Submission.add_discussion/2` membaca dengan `Map.get(current, :discussions)` lalu
  menulis dengan `Map.put(current, :discussions, ...)`. Dengan begitu tetap berfungsi walau
  struct lama masih ada di store tanpa perlu restart server.

### File yang diubah
- `lib/ojs_landing/submission.ex` — field `discussions` pada struct (default `[]` di `create/2`),
  fungsi `add_discussion/2`, private helper `next_discussion_id/1`.
- `lib/ojs_landing_web/router.ex` — route `post "/dashboard/editorial/:id/discussion"`.
- `lib/ojs_landing_web/controllers/editor_controller.ex` — aksi `add_discussion/2`.
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — tombol `btn-add-discussion-pre`
  + tabel diskusi + modal `#pre-discussion-overlay`; akses `discussions` via `Map.get`.
- `assets/js/app.js` — `openPreDiscussionModal/closePreDiscussionModal` (toggle class `prd-open`),
  klik backdrop & Escape untuk menutup.
- `assets/css/app.css` — section `.prd-*` (overlay, panel, header, body, input/textarea, footer,
  tombol `prd-btn-secondary`/`prd-btn-primary`).

### Verifikasi
- End-to-end pada server berjalan: GET workflow_1 200, POST discussion sukses, baris diskusi
  tampil setelah redirect (tanpa restart server, data submission 16 lama tetap aman).
- `mix precommit` lulus: 155 test, 0 failures.
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).

## Submission Files (`workflow_1`): tombol Upload + More Information/Delete dikembalikan untuk view editor

Kartu **Submission Files** di `workflow_1` sebelumnya menampilkan tampilan yang sama persis untuk
editor dan author (tanpa tombol Upload, dropdown titik-tiga hanya berisi Edit) karena perubahan
"author read-only workflow" diterapkan ke template bersama tanpa guard mode. Kini kartu bersifat
**mode-aware** (`@mode`):

### Editor (`/dashboard/editorial?workflowSubmissionId=<id>&workflowMenuKey=workflow_1`)
- Tombol **Upload** (`wf-btn-link`, id `btn-upload-submission-file`) muncul kembali di header
  kartu dan membuka modal upload yang sudah ada (`openUploadRevisionModal()`).
- Dropdown titik-tiga kembali menampilkan **Edit**, **More Information**, dan **Delete**
  (`wf-file-menu-danger`); More Information & Delete adalah placeholder
  (hanya `closeFileMenu`), pola sama seperti Revisions Uploaded / Files for Review di `workflow_3_1`.

### Author (`/submission/:id/workflow?workflowMenuKey=workflow_1`)
- Tetap read-only: tanpa tombol Upload, dropdown titik-tiga hanya berisi **Edit** (rename via modal).

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — tombol Upload dibungkus
  `<%= if @mode != :author do %>` di header kartu, dan item More Information/Delete ditambahkan di
  dropdown dengan guard yang sama.

### Status
- `mix precommit` lulus: 155 test, 0 failures.

## Pre-Review Discussions (`workflow_1`): tabel Name/From/Last Reply/Replies/Closed dari komentar author

Pada halaman workflow (`/submission/:id/workflow?workflowMenuKey=workflow_1`), kartu
**Pre-Review Discussions** kini menampilkan tabel berkolom `Name | From | Last Reply | Replies |
Closed` (reuse `.wf-table`, sama seperti Review Discussions di `workflow_3_1`).

### Perilaku
- Jika author mengisi **Comments for the editor** (field `editor_comments` dari tab Editors wizard,
  atau `comments_to_editor` dari form `/submission/new`), tabel dirender dengan satu baris:
  - **Name** = "Comments for The editor"
  - **From** = `@submission.author_username`
  - **Last Reply / Replies / Closed** = kosong
- Jika tidak ada isi sama sekali, div `.wf-empty` menampilkan teks **"No Items"**
  (menggantikan teks lama "No discussions have been started yet.").

### Catatan penting
- Field yang diisi author lewat wizard tab **Editors** ("Add any comments for the editor") adalah
  `editor_comments`, BUKAN `comments_to_editor`. Keduanya dicek oleh helper
  `EditorHTML.editor_comments_present?/1` supaya tabel muncul pada kedua kasus.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — kondisi `editor_comments_present?/1`
  menggantikan `<div class="wf-empty">No discussions have been started yet.</div>` di kartu
  Pre-Review Discussions (baris ±327–350).
- `lib/ojs_landing_web/controllers/editor_html.ex` — helper baru `editor_comments_present?/1`.

## Workflow author (`/submission/:id/workflow`): modal Edit File dengan rename tersimpan + badge Type biru

Pada workflow read-only author (`workflowMenuKey=workflow_1`), kartu **Submission Files** disesuaikan
dan menu tiga titik kini benar-benar berfungsi untuk mengganti nama file.

### Submission Files: tanpa tombol Upload, kolom aksi tiga titik, badge Type biru
- Tombol **Upload** di header kartu **Submission Files** dihapus.
- Tiap baris file kini memiliki kolom aksi di ujung kanan tabel (`wf-table-col-actions`) berisi
  tombol **tiga titik horizontal** (⋯) yang membuka dropdown.
- Dropdown hanya berisi **Edit** (item "More Information" & "Delete" dihapus).
- Kolom Type menampilkan **badge biru** bertuliskan **"Article Text"** (`.wf-file-type-badge`,
  `#006798`, putih) — konsisten dengan tabel Files for Review.

### Modal "Edit a File" (slide-in kanan→kiri)
- Klik **Edit** pada dropdown membuka modal `#edit-file-overlay` yang menyusup dari kanan
  (`translateX(100%) → 0`, reuse `.ar-overlay`/`.ar-panel`, lebar panel 560px via `.ef-panel`).
- Header biru `#006798`: tombol **panah kiri** (tutup modal) + judul **"Edit a File"** di tengah.
- Body berisi label **"Name the file (e.g., Manuscript; Table 1)"** dengan **tanda `*` merah**
  (`.ef-required`, `#c0392b`) menandakan field wajib, input teks (`.ef-input`) yang **terisi nama
  file yang sedang di-upload**, dan hint *"Current file: <nama>"*.
- Footer kanan-bawah: tombol **Cancel** dan **Save**.
- Validasi required: bila field kosong saat Save, input diberi border merah
  (`.ef-input-error`) + pesan "The file name is required." (`.ef-hint-error`).

### Save benar-benar menyimpan rename
- Tombol **Save** melakukan `fetch` POST ke endpoint baru **`POST /submission/:id/edit-file`**
  (`AuthorController.edit_file/2`) dengan JSON `{file_id, name}` + header `X-CSRF-Token`.
- Endpoint memanggil `Submission.rename_file/3` yang mencocokkan file berdasarkan `id` file
  (fallback ke posisi 1-based di daftar) dan memperbarui `filename` di store in-memory
  (`{:error, :invalid_name}` → 422 bila nama kosong).
- Setelah sukses, sel nama file di tabel (`#submission-file-name-<id>`) diperbarui via JS tanpa
  reload, lalu modal ditutup.

### Perbaikan bug: `KeyError :reviewers` saat mode author
- Modal **Add Reviewer** (editor-only, memakai `@reviewers`) sebelumnya dirender tanpa guard
  sehingga author mengalami `KeyError key :reviewers not found`. Kini seluruh modal dibungkus
  `<%= if @mode != :author do %>`.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — kartu Submission Files
  (hapus Upload, kolom aksi tiga titik, badge biru, dropdown Edit only), modal `#edit-file-overlay`
  di akhir template, id `submission-file-name-<idx>` pada sel file, guard modal Add Reviewer.
- `lib/ojs_landing_web/controllers/author_controller.ex` — action baru `edit_file/2`.
- `lib/ojs_landing_web/router.ex` — route `post "/submission/:id/edit-file"`.
- `lib/ojs_landing/submission.ex` — fungsi baru `rename_file/3`.
- `assets/js/app.js` — `openEditFileModal(id, name)`, `closeEditFileModal()`, `saveEditFile()`
  (fetch + validasi + update DOM), klik backdrop untuk menutup.
- `assets/css/app.css` — `.ef-panel`, `.ef-label`, `.ef-input`, `.ef-input-error`,
  `.ef-required`, `.ef-hint`, `.ef-hint-error`.

### Status
- `mix precommit` lulus: 155 test, tanpa warning.
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).

## Add Reviewer Modal: Statistics Panel di dropdown, sidebar filter di kiri, dan penyegaran pencarian

Penyempurnaan pada **Add Reviewer Modal** (dibuka dari tombol **Add reviewers** di kartu
**Reviewers**, `/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_3_1`).

### Tombol Filters pindah ke kanan + Search diperbesar
- Urutan kontrol "Locate a Reviewer" kini **Search box → Search button → Filters** (sebelumnya
  Filters di paling kiri sebelum search). Tombol **Filters** berada di ujung kanan.
- **Tombol Search biru dihapus** — input pencarian kini memfilter langsung saat mengetik
  (`oninput="arFilterReviewers()"`), tidak perlu klik tombol.
- Search box diperbesar: `flex: 1` (max-width `420px`), padding `12px 16px`, ikon & font lebih
  besar (18px / 17px).

### Sidebar filter muncul di kiri, list reviewer bergeser ke kanan
- Filters sidebar + daftar reviewer dibungkus `.ar-content-wrap` (`display: flex`).
- Sidebar filter (`240px`) ditampilkan di **kiri** saat tombol Filters diklik; daftar reviewer
  (`flex: 1`) **bergeser ke kanan** mengisi ruang yang tersisa.
- Klik tombol Filters lagi akan menutup sidebar dan daftar reviewer **kembali ke posisi awal**.
- Ada animasi fade + `translateX(-12px)` saat sidebar terbuka; tombol Filters mendapat state
  aktif `.is-open` (biru) via `arToggleFilters`.

### Tombol dropdown arrow (▼) di samping "Select Reviewer"
- Di samping kanan tombol **Select Reviewer** kini ada tombol **panah ke bawah** (▼,
  `.ar-select-reviewer-arrow`) yang menyatu sebagai split button (`border-right-left` digabung,
  radius kanan dibuat ujung kanan). Kedua tombol memanggil `arToggleDropdown(this)` yang sama
  (cari `.ar-reviewer-select-wrap` via `closest`), sehingga dropdown terbuka dari salah satunya.

### Reviewer Statistics Panel di dalam dropdown
- Saat dropdown dibuka, muncul panel **Reviewer Statistics Panel** (`.ar-dropdown-stat-panel`,
  `min-width: 300px`) berisi enam baris statistik:
  **Active reviews currently assigned**, **Reviews Completed**, **Review requests declined**,
  **Review requests cancelled**, **Days since last review assigned**,
  **Average days to complete review**, plus bagian **Reviewing Interests**.
- Data statistik ditambahkan ke payload `reviewer_json/1` di `EditorController`:
  `active_reviews` (status `action_required`/`in_progress`), `reviews_completed`
  (`completed`/`published`), `reviews_declined` (`declined`), `reviews_cancelled` (0),
  `days_since_last_review` (selisih `Date.utc_today()` dengan `date_assigned` terbaru),
  `avg_days_to_complete` (rata-rata `Date.diff(submitted_at, date_assigned)`),
  `reviewing_interests` (turunan dari affiliation + role).
- Di bawah panel tetap ada item aksi **Select Reviewer** dan **Cancel** seperti sebelumnya.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — urutan Filters/search;
  wrapper `.ar-content-wrap`; tombol arrow ▼; dropdown berisi `.ar-dropdown-stat-panel`.
- `lib/ojs_landing_web/controllers/editor_controller.ex` — field statistik baru di
  `reviewer_json/1` (`active_reviews`, `reviews_completed`, `reviews_declined`,
  `reviews_cancelled`, `days_since_last_review`, `avg_days_to_complete`, `reviewing_interests`).
- `assets/js/app.js` — `arToggleFilters` ikut men-toggle `.is-open` pada tombol Filters.
- `assets/css/app.css` — `.ar-content-wrap`, sidebar filter `flex` di kiri, `.ar-reviewer-list`
  `flex: 1`, `.ar-select-reviewer-arrow`, `.ar-select-dropdown-wide`,
  `.ar-dropdown-stat-*`, `.ar-dropdown-interests-*`.

### Status
- `mix compile --warnings-as-errors` bersih; `mix assets.build` sukses (perlu hard-refresh
  Ctrl+F5).

## Kartu Reviewers (`workflow_3_1`): Add Reviewer menjadi Slide-in Modal "Locate a Reviewer"

Pada halaman workflow review round 1 (`/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_3_1`),
tombol **Add reviewers** pada kartu **Reviewers** tidak lagi men-toggle form assign inline,
melainkan membuka **Add Reviewer Modal** yang muncul menyusup dari kanan ke kiri (slide-in,
`translateX(100%) → 0`, animasi 0.3s) bergaya OJS 3.5.

### Fitur
- **Header** biru `#006798` dengan tombol **panah kiri** (tutup) di kiri dan judul **"Add Reviewer"**
  di tengah, panel lebar `900px`.
- **"Locate a Reviewer"** heading di kiri, sejajar di kanan dengan tombol **Filters** dan kolom
  pencarian **Search** + tombol **Search**.
- **Tombol Filters** membuka sidebar filter berisi opsi dengan tombol **+**:
  **Rated at least**, **Reviews completed**, **Days since last review assigned**,
  **Active reviews currently assigned**, **Average days to complete review**. Setiap opsi punya
  deskripsi singkat; klik **+** menambahkan filter aktif dengan input nilai, didukung counter
  "n filters", tombol **Reset**, dan tombol hapus per filter.
- **Daftar reviewer**: hanya **user ber-role `:reviewer`** (filter dari `@reviewers` assign).
  Tiap kartu menampilkan:
  - **username** (kiri atas) dengan kotak **Select Reviewer** + dropdown (kiri-bawah
    *affiliation*).
  - Di bawahnya tiga kolom statistik: **Review Count**, **Last Review**, **Status**
    (badge Available hijau / Busy merah).
  - Tombol **Select Reviewer** membuka dropdown berisi "Select Reviewer" dan "Cancel". Memilih
    mensubmit form tersembunyi `POST /dashboard/editorial/:id/assign-reviewer` (dengan `reviewer_name`
    = username terpilih) sehingga benar-benar menugaskan reviewer.
- **Footer** kanan bawah: tombol **Create New Reviewer** dan **Enroll Existing User** (placeholder).
- Navigasi: tutup via panah kiri, klik backdrop, atau tombol **Escape**; dropdown menutup saat klik
  di luar.

### Data reviewer
`EditorController.reviewer_json/1` menghasilkan payload (username, affiliation, review_count,
last_review, status) dari `OjsLanding.User` + `ReviewerAssignment`. Daftar `@reviewers` dikirim ke
template workflow dengan memfilter `&(&1.role == :reviewer)` dari `OjsLanding.User.all()`,
sehingga admin/author/editor tidak muncul.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — modal `#add-reviewer-overlay`
  (markup `.ar-*`) di akhir template; tombol Add reviewers memanggil `arOpenAddReviewerModal()`;
  daftar reviewer `@reviewers`; sidebar filters + dropdown Select Reviewer.
- `lib/ojs_landing_web/controllers/editor_controller.ex` — render workflow menambahkan assign
  `reviewers` (filter role `:reviewer` + `reviewer_json`).
- `assets/js/app.js` — `arOpenAddReviewerModal`/`closeAddReviewerModal`, `arToggleFilters`,
  `arAddFilter`/`removeArActiveFilter`/`arResetFilters`/`arUpdateFilterCount`,
  `arToggleDropdown`/`arCloseAllDropdowns`/`arSelectReviewer`, handler klik backdrop + Escape.
- `assets/css/app.css` — section `.ar-*` (overlay slide-in, header, Locate a Reviewer, sidebar
  filters, daftar reviewer, dropdown Select Reviewer, footer tombol).

### Perbaikan bug
- Tombol modal sempat memanggil `openAddReviewerModal()` sementara fungsi JS bernama
  `arOpenAddReviewerModal()` (ganti nama saat fitur filters ditambahkan) — keduanya kini konsisten.

### Status
- `mix precommit` lulus: 155 test, tanpa warning.
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).

## Dialog "Review File Selection" (`workflow_3_1`): pemilihan file review + filter semua tahap workflow

Pada halaman workflow review round 1 (`/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_3_1`),
tombol **Upload/Select Files** pada kartu **Files for Review** kini membuka **Review File Selection
Dialog** yang muncul menyusup dari sisi kanan ke kiri (slide-in, `translateX(100%) → 0`, animasi
0.3s) — gaya OJS 3.5.

### Fitur
- Header biru `#006798` dengan tombol **panah kiri** (tutup dialog) di kiri dan judul di tengah:
  **"Current Review Files For Round 1"**.
- Section header **"Review Files"** di kiri, sejajar dengan tombol **Upload Review Files** di
  kanan (membuka drawer **Upload Review File** yang sudah ada).
- Di bawahnya opsi filter bertuliskan **"Show files from all accessible workflow stages"**.
- Daftar file per tahap:
  - Default (filter mati): hanya section **Review** berisi baris-baris file review (`has_revisions
    != true`) — tiap baris: dropdown **arrow chevron** (kanan saat tertutup → bawah saat terbuka,
    berisi menu **More Information**), **checkbox** pilihan, lalu **nama file** + badge type
    "Article Text".
  - Saat filter **dicentang**: muncul empat section berurutan **Submission** (semua file), **Review**
    (file review), **Copyediting** dan **Production** (keduanya menampilkan teks **"No Items"**
    karena submission belum mencapai tahap tersebut).
- Footer kanan bawah: tombol **Cancel** dan **Ok** (keduanya menutup dialog).

### Perbaikan perilaku
- Dropdown tidak lagi terpotong: `.rfs-file-list` memakai `overflow: visible` (sebelumnya `hidden`
  memotong menu yang muncul di bawah baris).
- `openFileMenu/1` kini bersifat **toggle** — menu yang sudah terbuka dapat ditutup dengan klik
  tombol panah yang sama (sebelumnya selalu tetap terbuka).
- ID menu dibedakan antar daftar (`rfs-file-menu-s-*`, `-sub-*`, `-arev-*`) agar tidak bentrok.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — dialog `#review-file-selection-overlay`
  (markup `.rfs-*`) di akhir template; tombol `#btn-upload-review-files` memanggil
  `openReviewFileSelection()`; dua mode daftar (`#rfs-single-stages` / `#rfs-all-stages`) ditoggle
  via `onchange="toggleRfsStages()"` pada checkbox filter.
- `assets/js/app.js` — `openReviewFileSelection/closeReviewFileSelection`,
  `toggleRfsStages` (toggle mode single vs semua tahap); `openFileMenu` diubah menjadi toggle;
  handler klik area gelap untuk menutup dialog.
- `assets/css/app.css` — section `.rfs-*` (overlay/backdrop, dialog slide, header, body, section
  head, filter, baris file, tombol `rfs-btn-cancel`/`rfs-btn-ok`), `.rfs-stages-hidden`,
  `.rfs-stage-group`, arrow chevron `.rfs-menu-arrow` + rotasi 90° saat `wf-open`.

### Status
- `mix precommit` lulus: 155 test, tanpa warning.
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).

## Kartu Reviewers (`workflow_3_1`): empty state di dalam tabel

Pada halaman workflow review round 1 (`/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_3_1`),
kartu **Reviewers** kini **selalu** merender tabel dengan header
`REVIEWERS | REVIEWER STATUS | TYPE | ACTIONS` — termasuk saat belum ada reviewer yang
ditugaskan.

### Detail
- Sebelumnya, saat `@review_assignments == []`, kartu merender `<div class="wf-empty">` di luar
  tabel sehingga muncul seperti baris "No Items" dengan kolom STATUS/TYPE/ACTIONS kosong.
- Sekarang tabel selalu dirender. Saat belum ada assignment, satu baris `colspan="4"` berkelas
  `.wf-table-empty` menampilkan teks "No reviewers have been assigned yet." — konsisten dengan
  kartu *Revisions Uploaded* (colspan 5) dan *Review Discussions* (colspan 5).

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — tabel Reviewers selalu
  dirender; empty state menjadi `<tr>` dengan `colspan="4"` + `.wf-table-empty`.

### Status
- `mix compile` lulus (perlu hard-refresh Ctrl+F5).

## Workflow `workflow_3_1`: tombol aksi tiga titik (horizontal) di tabel file

Pada halaman workflow review round 1 (`/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_3_1`),
kedua kartu file — **Revisions Uploaded** dan **Files for Review** — kini memiliki kolom aksi di
**ujung kanan tabel** berisi tombol **tiga titik horizontal** (⋯). Klik tombol membuka dropdown
dengan opsi **Edit**, **More Information**, dan **Delete** (Delete berwarna merah di baris
terbawah). Menutup dropdown terjadi saat memilih salah satu opsi atau klik di luar dropdown.

### Detail
- Kolom TYPE tetap menampilkan genre file (mis. "Manuscript"); tombol tiga titik dipindah ke
  kolom terpisah `.wf-table-col-actions` (lebar 48px, rata kanan) di ujung kanan, bukan lagi di
  samping teks genre.
- Header tabel bertambah satu `<th class="wf-table-col-actions">` kosong; baris kosong (empty
  state) memperbarui `colspan` menjadi 5.
- Ikon titik tiga dibuat **horizontal** (⋯, tiga lingkaran sebaris) melalui SVG `circle` dengan
  `cx` berbeda dan `cy` sama.
- Dropdown `.wf-file-menu-dropdown` dibuka dengan class `wf-open`, diposisikan rata kanan di
  bawah tombol, `min-width: 168px`, border `#ddd` + shadow, item hover biru muda. Opsi Delete
  (`wf-file-menu-danger`) berwarna merah `#c0392b` + separator atas.
- Auto-close: klik di luar `.wf-file-menu` menutup semua dropdown (`closeAllFileMenus`).
- Kode diulang di kedua tabel (Revisions Uploaded & Files for Review) dengan id menu yang
  disegment (`file-menu-revision-N` / `file-menu-review-N`).

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — kolom aksi kanan + tombol
  tiga titik + dropdown pada tabel Revisions Uploaded & Files for Review.
- `assets/js/app.js` — `openFileMenu(id)`, `closeFileMenu(id)`, `closeAllFileMenus()`, dan
  listener klik global untuk auto-close.
- `assets/css/app.css` — `.wf-table-col-actions`, `.wf-file-menu`, `.wf-file-menu-btn`,
  `.wf-file-menu-dropdown`, `.wf-file-menu-item`, `.wf-file-menu-danger`.

### Status
- `mix precommit` lulus: 155 test, tanpa warning.
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).

## Drawer "Upload Review File" (`workflow_3_1`): penyesuaian ukuran, stepper klik, dan tombol "Add Another File"

Penyempurnaan pada drawer **Upload Review File** yang terbuka dari tombol **Upload** di kartu
**Revision Uploaded** (`/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_3_1`).

### Ukuran & spasi
- Modal (`.urf-modal`) diubah dari `max-width: 660px` menjadi **`width: 900px; max-width: 95%`**
  (lebih lebar, tetap menyesuaikan layar kecil).
- Padding diseragamkan: header `16px 20px`, body `20px`, footer `16px 20px`.
- Dropdown Article Component (`.urf-select`) kini `width: 100%` dengan `padding: 8px 12px`.
- Tombol-tombol (`.urf-btn-upload`, `.urf-btn-change-file`, `.urf-btn-cancel`,
  `.urf-btn-continue`) diseragamkan `padding: 8px 20px`.

### Stepper bisa diklik (setelah melewati langkah sebelumnya)
- Step stepper kini **dapat diklik** (`.urf-step-clickable`, cursor pointer, hover biru) namun
  hanya untuk langkah **yang sudah dicapai** (`step <= urfStep`).
- Sebelum mencapai tahap 3, langkah 2 dan 3 **tidak bisa** diklik — pengguna wajib maju secara
  berurutan lewat tombol **Continue** dari Step 1. Setelah sampai di Step 3, semua langkah
  1–3 dapat diklik untuk navigasi balik.
- Fungsi baru `urfGoToStep(step)` menolak lompatan ke depan (`step > urfStep` dan step 3 saat
  belum di step 3).

### Step 3 (Confirm): "File Added" + "Add Another File"
- Teks dikonfirmasi menjadi **"File Added"** (ikon ceklis hijau dihapus) di tengah kotak
  konfirmasi, dengan tombol **Add Another File** (`.urf-btn-upload`, id `urf-btn-add-another`)
  di bawahnya.
- Klik **Add Another File** menyimpan file yang sudah dikonfirmasi ke daftar sementara
  (`urfAddedFiles`), lalu mengembalikan ke Step 1 untuk memilih file berikutnya — file lama
  **tidak hilang**.
- Daftar file yang sudah ditambah ditampilkan di Step 1 sebagai counter "Added files (n)" +
  chip (komponen — nama file) pada `.urf-added-files`.
- Tombol footer **Confirm Upload** (Step 3) juga menyimpan file terakhir sebelum menutup
  drawer.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — stepper dengan
  `onclick="urfGoToStep(...)"`, step 3 confirm box ("File Added" + tombol Add Another File),
  container `.urf-added-files` di Step 1.
- `assets/js/app.js` — `urfAddedFiles`, `urfStoreCurrentFile/0`, `renderUrfAddedFiles/0`,
  `urfGoToStep/1`, `urfAddAnotherFile/0` (simpan file lalu reset ke Step 1); `showUrfStep`
  mengatur kelas `urf-step-clickable`; `resetUploadRevision` mengosongkan daftar.
- `assets/css/app.css` — `.urf-modal` (`900px`/`95%`), padding header/body/footer,
  `.urf-select` full-width, padding tombol `8px 20px`, `.urf-step-clickable`,
  `.urf-added-files` & `.urf-added-file-chip`.

### Status
- `mix compile` bersih; `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).

## Send for Review Step 1: daftar template di bawah kotak "Find Template" dihapus

Pada `GET /dashboard/editorial/:id/send-to-review` (Step 1 Notify Authors), daftar
**Email Templates** yang tampil di bawah kotak pencarian **Find Template** (beserta hint
"Select a template to fill the subject and message body.") dihapus. Kotak pencarian beserta
header panel tetap dipertahankan; kolom Subject/message rich text editor diisi manual.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/send_to_review_email.html.heex` — blok
  `<ul class="enr-template-list">` (iterasi `@email_templates`) dan hint dihapus.
- Controller (`EditorController.send_to_review_email/2`) tidak diubah — `@email_templates`
  tetap dikirim tapi kini tidak dirender.

### Status
- Template dikompilasi ulang (perlu hard-refresh Ctrl+F5).

## Workflow `workflow_3_1`: tombol "Upload" Revision Uploaded membuka drawer "Upload Review File"

Pada halaman workflow review round 1 (`/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_3_1`),
tombol **Upload** pada kartu **Revision Uploaded** kini membuka **Upload Review File drawer** yang
muncul menyusup dari kanan ke kiri (slides in from right), bukan pop-up modal di tengah layar.

### Fitur
- Drawer muncul dari sisi kanan layar (`.urf-modal` `translateX(100%) → 0`, animasi 0.3s), lebar
  `max-width: 660px`, tinggi penuh, dengan backdrop gelap di belakangnya.
- Header berjudul **Upload Review File**; tombol close berupa **panah kiri** (`.urf-back`, ikon
  chevron kiri) — karena drawer datang dari kanan. Klik panah/Cancel/area gelap akan menggeser
  drawer kembali ke kanan lalu me-reset state.
- Stepper 3 langkah: **1. Upload File** · **2. Review Details** · **3. Confirm** (nomor lingkaran +
  connector, aktif biru `#006798`, selesai hijau).
- **Step 1 — Upload File**: field **Article Component** (dropdown "Select article component" dengan
  opsi Article Text, Research Instrument, Research Materials, Research Results, Transcripts, Data
  Analysis, Data Set, Source Text, Other). Setelah memilih salah satu opsi, muncul tombol **Upload
  File** di sebelah kanannya; setelah file dipilih tombol berubah menjadi **Change file** dan nama +
  ukuran file ditampilkan.
- **Step 2 — Review Details**: ringkasan Article Component / File Name / File Size.
- **Step 3 — Confirm**: pemberitahuan "Your file is ready to be uploaded."
- Footer aksi: **Cancel** (tutup drawer) dan **Continue** — hanya dapat diklik pada Step 1 bila
  Article Component sudah dipilih **dan** file sudah di-upload; label menjadi "Confirm Upload" pada
  Step 3.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — tombol Upload memanggil
  `openUploadRevisionModal()`; markup drawer `#upload-revision-overlay` (header panah kiri, stepper,
  3 step body, footer aksi) di akhir template.
- `assets/js/app.js` — `openUploadRevisionModal/closeUploadRevisionModal` (toggle class `urf-open`),
  `onArticleComponentChange`, `onFileSelected`, `urfNextStep`, `updateUrfContinue`, `showUrfStep`,
  `formatUrfBytes`, `resetUploadRevision` (semua fungsi yang dipakai inline handler di-attach ke
  `window` karena `app.js` adalah ES module).
- `assets/css/app.css` — section `.urf-*` ditulis sebagai drawer kanan (overlay `justify-content:
  flex-end`, modal `translateX`, `.urf-back`, `.urf-step-*`, `.urf-btn-*`).

### Status
- `mix compile` bersih; `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).

## Workflow: kartu Participants di sidebar kiri disembunyikan untuk `workflow_1` & `workflow_3_1`

Pada halaman workflow editor, kartu **Participants** yang tadinya selalu tampil di **sidebar kiri**
kini **disembunyikan** saat menu aktif `workflow_1` (Submission) maupun `workflow_3_1` (Review Round
1), karena kedua view tersebut sudah menampilkan kartu Participants di **kolom kanan**
(`wf-col-side`) — menghindari duplikasi peserta (author/editor) di kiri dan kanan sekaligus.

### Fitur
- Kondisi sidebar Participants kini `@mode != :author and @active_menu not in ["workflow_1",
  "workflow_3_1"]` di `workflow.html.heex`.
- Pada `workflow_1` dan `workflow_3_1`, daftar peserta hanya tampil di kolom kanan bawah Action
  Panel (mode editor); sidebar kiri hanya berisi menu Workflow/Publication.
- View lain (workflow_4, workflow_5, publikasi) tetap menampilkan Participants di sidebar kiri.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — blok sidebar Participants
  ditambah guard `@active_menu not in ["workflow_1", "workflow_3_1"]`.

### Status
- `mix compile` bersih.

## Workflow `workflow_3_1`: kartu "Files for Review" di atas Reviewers

Pada halaman workflow review round 1 (`/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_3_1`),
ditambahkan kartu baru **Files for Review** tepat di atas kartu **Reviewers** di kolom kiri.

### Fitur
- Kartu `.wf-card` berjudul **Files for Review** dengan subtitle *"These files will be sent to the
  reviewers to review."* (`.wf-card-subtitle`) tepat di bawah judul.
- Sejajar dengan judul, di kanan header terdapat tombol **Upload/Select Files** (`.wf-btn-link`,
  id `btn-upload-review-files`, ber-ikon upload) — konsisten dengan tombol Upload pada kartu lain.
- Body menampilkan tabel file (kolom # / File Name / Date Uploaded / Type) untuk file non-revisi
  (`Enum.filter(@submission.files || [], &(&1[:has_revisions] != true))`). Jika tidak ada file:
  *"No files have been uploaded for review yet."*

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — kartu **Files for Review**
  disisipkan di antara kartu Revision Uploaded dan Reviewers pada blok `workflow_3_1`.
- `assets/css/app.css` — rule baru `.wf-card-subtitle` (font-size 0.8125rem, warna #666).

### Status
- `mix precommit` lulus: 155 test, tanpa warning.

## Workflow `workflow_3_1`: kartu Participants dipindah ke kolom kanan bawah Action Panel

Pada halaman workflow review round 1 (`/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_3_1`),
kartu **Participants** kini ditampilkan di kolom kanan (`.wf-col-side`) tepat di bawah kartu
**Action Panel** (mode editor), bukan lagi hanya di sidebar kiri.

### Fitur
- Kartu `.wf-card` berjudul **Participants** dengan tombol **Assign** (`.wf-btn-link`, id
  `btn-assign-participant-review`, ber-ikon user-plus) di kanan header.
- Daftar `.wf-participants-list` menampilkan author/contributor (dengan primary contact) lalu
  editor (`@submission.editors`) berlabel "Editor" — struktur sama seperti kartu Participants pada
  `workflow_1`.
- Ditampilkan untuk mode editor (`@mode != :author`) pada kolom kanan; kartu ini selalu muncul di
  bawah Action Panel (tidak bergantung pada `@row.status`).
- Mode author tetap menampilkan kartu **Review Progress** di kolom kanan (tanpa Participants).

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — kartu **Participants** baru
  pada blok `workflow_3_1`, kolom kanan setelah Action Panel.

### Status
- `mix precommit` lulus: 155 test, tanpa warning.

## Workflow `workflow_3_1` (External Review Round 1): redesign tata letak + Action Panel pindah ke kanan

Halaman workflow review round 1 (`/dashboard/editorial?workflowSubmissionId=...&workflowMenuKey=workflow_3_1`)
dirombak dari satu kartu "Review Round 1" menjadi layout dua kolom bergaya OJS 3.5
(`.wf-two-col-layout`, sama seperti `workflow_1`).

### Header & Kolom Kiri (`.wf-col-main`)
- Header baru `.wf-page-heading` berjudul **"WORKFLOW: REVIEW (ROUND 1)"** di atas konten
  (garis kiri oranye `#e08914`, teks uppercase biru).
- **Status Info** — kartu berisi kotak `.wf-status-box` dengan judul **Round 1 Status**:
  - "Waiting for reviewers to be assigned." saat `@review_assignments == []`.
  - "{n} reviewer assignment(s) in this round." bila sudah ada assignment.
- **Revision Uploaded** — kartu dengan tombol **Upload** (`.wf-btn-link`, id `btn-upload-revision`)
  sejajar judul di header; menampilkan tabel file yang `has_revisions == true` (kolom # / File
  Name / Date Uploaded / Type). Jika tidak ada file revisi: pesan *"No revisions have been
  uploaded. These files are submitted by the author after revisions were requested."*
- **Reviewers** — kartu dengan tombol **Add reviewers** (`.wf-btn-link`, id `btn-add-reviewers`)
  di kanan header (hanya untuk editor, `@mode != :author`); tombol men-toggle form assign inline
  (`#assign-reviewer-inline`, class `.wf-inline-assign` + `.wf-hidden`) yang POST ke
  `/dashboard/editorial/:id/assign-reviewer`. Tabel reviewer (Reviewer / Round / Status / Due
  Date / Recommendation / Action → "Open") ditampilkan bila assignment ada, else *"No reviewers
  have been assigned yet."*
- **Review Discussions** — kartu dengan tombol **Add Discussion** (`btn-add-discussion-review`)
  di kanan header; body *"No discussions have been started yet."*

### Kolom Kanan (`.wf-col-side`)
- **Action Panel** (editor saja, `@mode != :author`, dan `@row.status not in [:declined,
  :published, :scheduled]`) berisi tombol `.wf-btn-action` selebar penuh:
  - **Request Revisions** (form POST `/request-revisions`, id `btn-request-revisions`).
  - **Accept Submission** (form POST `/accept`, id `btn-accept-submission`).
  - **Create New Review Round** (placeholder, id `btn-create-new-review-round`).
  - **Cancel Review Round** (placeholder, id `btn-cancel-review-round`).
  - **Decline Submission** (form POST `/decline` + konfirmasi, id `btn-decline-review`).
- Untuk mode author, kolom kanan menampilkan kartu **Review Progress** read-only alih-alih
  Action Panel.

### Catatan teknis HEEx
- **Bug unik:** `<% if %>` (non-output) yang bersarang di dalam `<% else %>` dari `<%= if %>`
  TIDAK dirender oleh HEEx (konten hilang tanpa error, menyisakan `<div>` kosong). Solusinya:
  gunakan `<%= if %>` (output) untuk blok dalam — pola yang sama dipakai kode lama.
- `Enum.filter(@submission.files || [], &(&1[:has_revisions] == true))` memilih file revisi.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — blok `workflow_3_1`
  ditulis ulang (heading, 4 kartu kiri, Action Panel kanan).
- `assets/css/app.css` — `.wf-page-heading`, `.wf-page-stage-label`, `.wf-status-box` (+ title/
  text), `.wf-inline-assign`, `.wf-hidden`, `.wf-action-form`.
- `test/ojs_landing_web/controllers/editor_controller_test.exs` — describe baru
  "workflow_3_1 external review layout" yang memeriksa seluruh elemen baru di atas.

### Status
- `mix precommit` lulus: 155 test, tanpa warning.
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).

## Send for Review (Step 1 & Step 2): toolbar rich text, tombol aksi Select Files, kolom Date

Penyesuaian tampilan pada wizard **Send for Review** Step 1 (Notify Authors) dan Step 2
(Select Files).

### Step 1 — Toolbar rich text editor (`send_to_review_email.html.heex`)
- Toolbar `.enr-message-toolbar` diubah dari Bold/Italic/Underline/Bullet menjadi:
  **B** (bold), **I** (italic), **X** superscript, **X** subscript, **insert/edit link**,
  **Attach file**, dan **Insert Content**.
- Superscript/subscript ditampilkan sebagai "X" dengan posisi naik/turun
  (`.enr-toolbar-super` / `.enr-toolbar-sub`); Attach file & Insert Content memakai ikon
  (paperclip / document) + label teks (`.enr-toolbar-btn-text`).
- Fungsional via `initRichtextEditors()` di `assets/js/app.js` (sudah mengenali perintah
  `superscript`, `subscript`, dan `createLink`); tombol Attach file & Insert Content bersifat
  visual.

### Step 2 — Select Files (`send_to_review_files.html.heex`)
- Tombol submit **"Send for Review"** diubah menjadi **"Record Decision"** (tetap POST ke
  `POST /dashboard/editorial/:id/send-to-review`).
- Tombol **Go Back** dihapus; diganti **Previous** (kembali ke Step 1) dan **Cancel** (kembali
  ke workflow_1) — semua tombol kini berjajar rapat di kanan footer aksi
  (`.enr-actions-file { justify-content: flex-end }`).
- Header tabel (Select / File Name / Date / Type) dihapus — tabel langsung menampilkan baris file.
- Kolom **Date** menampilkan `Uploaded by {author_username} on {YYYY-MM-DD}`; jika `date` file
  kosong, fallback ke `submission.date_submitted`/`submission.created_at`
  (`DateTime.to_date() |> Date.to_string()`).
- Halaman diberi kelas `.enr-page-wide` (`.enr-page` `max-width: 1080px`, `width: 100%`) agar
  kartu Submission Files lebih lebar.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/send_to_review_email.html.heex` — toolbar baru.
- `lib/ojs_landing_web/controllers/editor_html/send_to_review_files.html.heex` — Record Decision,
  Previous/Cancel, tanpa header tabel, kolom Date ber-uploader.
- `assets/css/app.css` — `.enr-toolbar-btn-text`, `.enr-toolbar-super`/`.enr-toolbar-sub`,
  `.enr-page-wide`, `.enr-actions-file { justify-content: flex-end }`.

### Status
- `mix compile --warnings-as-errors` bersih.
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).

## Send for Review: Email Notification Page — penyegaran tampilan (UI polish)

Penyegaran visual menyeluruh pada halaman wizard "Send for Review" agar lebih rapi
(`GET /dashboard/editorial/:id/send-to-review` dan `GET .../send-to-review/select-files`).
Perilaku fungsional tidak berubah — tombol **Send for Review** tetap POST
(`POST /dashboard/editorial/:id/send-to-review`), serta alur Continue/Cancel/Go Back tetap sama.
Semua DOM id dan atribut data yang dipakai JS (`enr-template-search`, `enr-template-list`,
`enr-to`, `enr-subject`, `enr-message`, `enr-message-editor`, `enr-message-toolbar`,
`[data-enr-template-select]`, `.enr-template-item[data-search]`, dst.) dipertahankan.

### Perubahan tampilan Step 1 (Notify Authors)
- **Ringkasan submission** (`enr-summary`) di bawah subtitle: ID submission, judul, author
  (dari `@row.author`), dan pill stage warna-warni (`stage_label`/`stage_color` editor).
- **Stepper** didesain ulang dengan lingkaran nomor + garis penghubung (connector): step aktif
  biru `#006798` dengan shadow, step selesai hijau.
- **Panel Email Templates**: header ber-icon + badge jumlah, input pencarian dengan ikon dan
  *focus ring* biru, tiap template ber-icon amplop + deskripsi + indikator radio; item terpilih
  (default "Submission Sent for Review") diberi highlight biru muda.
- **Panel Kompose Email**: header "Email Message" + hint "Step 1 of 2", field To/Subject dengan
  *focus ring*, rich text editor dengan *focus-within*, footer aksi dengan hint teks + tombol
  **Cancel** / **Continue** (ber-icon panah).
- Kartu putih seragam dengan `border-radius: 6px`, border `#e2e7ea`, shadow halus; tombol
  `enr-btn` dengan efek hover/shadow; transisi halus di hover/focus.

### Perubahan tampilan Step 2 (Select Files)
- Stepper menunjukkan Step 1 selesai (✓ hijau) dengan connector hijau dan Step 2 aktif.
- Layout tabel files dibungkus `.enr-files-body`; header card + badge jumlah file; genre file
  sebagai pill rounded; baris tabel dengan hover.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html/send_to_review_email.html.heex` — markup baru:
  summary strip, stepper connector, template item (icon + radio + selected), compose header,
  footer actions dengan hint.
- `lib/ojs_landing_web/controllers/editor_html/send_to_review_files.html.heex` — stepper
  connector done; wrapper `.enr-files-body`.
- `assets/js/app.js` — `initEmailNotification/0`: klik template kini juga men-toggle kelas
  `enr-template-selected` (satu pilihan aktif pada satu waktu).
- `assets/css/app.css` — section `.enr-*` ditulis ulang (warna `#006798`, radius 6px,
  focus ring, shadow, pill, stepper connector, responsive).

### Status
- `mix compile` & `mix assets.build` sukses.
- `mix precommit` lulus: 154 test, tanpa warning (perlu hard-refresh Ctrl+F5).

## Send for Review: Email Notification Page (wizard 2 langkah "Notify Authors" → "Select Files")

Tombol **Send For Review** pada Action Panel workflow_1 (`workflowMenuKey=workflow_1`) tidak lagi
langsung memindahkan submission ke tahap review, melainkan membuka **Email Notification Page**
(wizard 2 langkah ala OJS 3.5) sebelum transisi benar-benar terjadi.

### Fitur
- **Step 1 – Send for Review: Notify Authors** (`GET /dashboard/editorial/:id/send-to-review`,
  `EditorController.send_to_review_email/2`, template `send_to_review_email.html.heex`):
  - Breadcrumb: **Dashboard / (author), (judul submission) / Send for review** (author diambil
    dari primary contact contributor, judul dari submission; tautan author kembali ke workflow_1).
  - Page title **`# Send for Review: Notify authors`** + deskripsi *"This submission is ready to be
    sent for peer review."*.
  - Stepper **1. Notify Authors** (aktif) · **2. Select Files**.
  - Kiri: card **Email Templates** berisi kotak pencarian **Find Template** (memfilter daftar
    template secara client-side) + daftar template; mengklik template mengisi kolom **Subject**
    dan isi rich text editor via JS (`applyPredefinedMessage`-style, lebih tepatnya handler
    `[data-enr-template-select]`).
  - Kanan: kolom **To** (read-only, nama primary contact via `EditorController.primary_contact/1`),
    kolom **Subject** (default *"Your submission has been sent for review"*), rich text editor
    `.enr-richtext[data-target]` (toolbar bold/italic/underline/bullet, disinkronkan oleh
    `initRichtextEditors()` di `app.js` yang kini juga mengenali `.enr-richtext`).
  - Aksi kanan bawah: **Cancel** (kembali ke `workflow_1`) dan **Continue** (ke Step 2).
- **Step 2 – Send for Review: Select Files** (`GET .../send-to-review/select-files`,
  `EditorController.send_to_review_files/2`, template `send_to_review_files.html.heex`):
  - Stepper menandai Step 1 selesai (✓ hijau) dan Step 2 aktif.
  - Tabel **Submission Files** dengan checkbox tercentang per file (kolom Select / File Name /
    Date / Type; genre file sebagai badge).
  - Aksi: **Go Back** (kembali ke Step 1) dan tombol **Send for Review** yang mem-POST ke
    `POST /dashboard/editorial/:id/send-to-review`.
- **Transisi**: `POST /dashboard/editorial/:id/send-to-review` (`send_to_review/2`) tetap
  menjalankan transisi (status `:active`, stage `:external_review`) — kini hanya diakses dari
  Step 2 wizard, bukan lagi langsung dari Action Panel.
- CSS baru di `assets/css/app.css` dengan prefiks `enr-` (halaman, breadcrumb, stepper, layout
  grid `300px 1fr`, templates card, compose card, rich text editor, tombol aksi, tabel files),
  gaya mengikuti OJS 3.5 PKP (`#006798`, Noto Sans, `border-radius: 2px`).

### File yang diubah
- `lib/ojs_landing_web/router.ex` — route GET baru `send-to-review` & `send-to-review/select-files`.
- `lib/ojs_landing_web/controllers/editor_controller.ex` — aksi `send_to_review_email/2` &
  `send_to_review_files/2`; helper `primary_contact/1`, `recipient_text/1`,
  `send_to_review_templates/0`.
- `lib/ojs_landing_web/controllers/editor_html/send_to_review_email.html.heex` (baru) — Step 1.
- `lib/ojs_landing_web/controllers/editor_html/send_to_review_files.html.heex` (baru) — Step 2.
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — tombol **Send For Review**
  diubah dari form POST menjadi link (anchor) ke Step 1 wizard.
- `assets/js/app.js` — selector `initRichtextEditors` diperluas ke `.enr-richtext`; IIFE baru
  `initEmailNotification` (pilihan template mengisi subject+pesan, pencarian template client-side).
- `assets/css/app.css` — section `.enr-*` untuk Email Notification Page.
- `test/ojs_landing_web/controllers/editor_controller_test.exs` — test Step 1, Step 2, dan
  POST send-to-review masih men-transisi ke `:external_review`.

### Status
- `mix precommit` lulus: 154 test, tanpa warning.
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).

## Editorial Dashboard & Workflow: Timing "Assign Reviewers", label "Review (Round 1)", dan komponen rendering stage/workflow

### 1. Tombol "Assign Reviewers" hanya muncul setelah "Send for Review"
- **Sebelum:** `EditorHTML.editorial_actions/1` memeriksa `stage in [:initial_review, :external_review] and not row.has_reviewers`. Karena submission langsung ber-stage `:initial_review` saat di-submit author, tombol **Assign Reviewers** muncul segera setelah editor ditugaskan — sebelum alur send-to-review terjadi.
- **Sesudah:** Kondisi diubah menjadi `stage == :external_review and not row.has_reviewers`. Sekarang:
  - Setelah assign editor (stage `:initial_review`/Submission), kolom EDITORIAL ACTIVITY **kosong**.
  - Setelah editor meng-klik **Send for Review** di workflow view (stage berubah ke `:external_review`), barulah tombol **Assign Reviewers** muncul.

### 2. Kolom EDITORIAL ACTIVITY kosong setelah editor ditugaskan
- **Sebelum:** Setelah editor ditugaskan, cabang fallback `true ->` di `editorial_actions/1` mengembalikan aksi spesifik stage (mis. "Send for Review").
- **Sesudah:** Cabang `true ->` mengembalikan `nil`, sehingga setelah has_editor=true kolom EDITORIAL ACTIVITY kosong (kecuali kondisi lain yang lebih awal terpenuhi: Assign Editor, Complete Submission, atau Assign Reviewers saat `:external_review`). Fungsi `next_action_for_stage/1` yang kini tidak terpakai dihapus (hindari warning unused).

### 3. Label stage & menu workflow "External Review" → "Review (Round 1)"
- `EditorHTML.stage_label(:external_review)` diubah dari `"External Review"` menjadi `"Review (Round 1)"` — berdampak konsisten pada kolom **STAGE** dashboard editorial, workflow page, dan activity page.
- Label tab workflow menu `workflow_3_1` diubah dari `"External Review"` menjadi `"Review Round 1"` (menyamakan judul kartu "Review Round 1" pada `workflow.html.heex`) di `EditorController` dan `AuthorController`.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html.ex` — `editorial_actions/1` (kondisi `stage == :external_review`, cabang `true -> nil`), `stage_label/1` ("Review (Round 1)"), hapus `next_action_for_stage/1`.
- `lib/ojs_landing_web/controllers/editor_controller.ex` — label menu `workflow_3_1` → "Review Round 1".
- `lib/ojs_landing_web/controllers/author_controller.ex` — label menu `workflow_3_1` → "Review Round 1".

### Status
- `mix precommit` lulus: 151 test, tanpa warning.

## Editorial Dashboard: EDITORIAL ACTIVITY kolom kosong setelah Assign Editor

### Bug
- Pada `/dashboard/editorial?currentViewId=active`, setelah editor ditugaskan ke submission, kolom **EDITORIAL ACTIVITY** menjadi kosong (tidak ada tombol **Assign Reviewers** maupun aksi lain).
- Sebelum perbaikan: `has_reviewers?/1` membandingkan status assignment (`:action_required`, `:in_progress`, `:completed`) sebagai atom, tapi data mungkin disimpan sebagai string; dan `editorial_actions/1` memeriksa `row.stage in [:initial_review, :external_review]` yang gagal jika stage berupa string.

### Perbaikan
- `lib/ojs_landing_web/controllers/editor_controller.ex` — `has_reviewers?/1` menormalkan status ke atom via `normalize_status/1` (handle atom & string).
- `lib/ojs_landing_web/controllers/editor_html.ex` — `editorial_actions/1` menormalkan stage ke atom via `normalize_stage/1` sebelum membandingkan dengan daftar atom stage.

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_controller.ex` — helper `normalize_status/1` + `has_reviewers?/1`.
- `lib/ojs_landing_web/controllers/editor_html.ex` — helper `normalize_stage/1` + `editorial_actions/1`.

### Status
- `mix precommit` lulus: 151 test, tanpa warning.

## Editorial Dashboard: Assign Editor & Participants di Workflow Page

### 1. Kolom EDITORIAL ACTIVITY: "Assign Editor" hilang setelah editor ditugaskan
- **Sebelum:** Penugasan editor tidak mempengaruhi tampilan kolom **EDITORIAL ACTIVITY** — tombol **Assign Editor** tetap tampil meski editor sudah ditambahkan.
- **Sesudah:** `EditorHTML.editorial_actions/1` memeriksa `not row.has_editor` sebagai kondisi **pertama** (terlepas dari stage). Setelah `Submission.assign_editor/2` menambahkan editor ke `submission.editors`, `has_editor?` mengembalikan `true` sehingga tombol **Assign Editor** **tidak lagi tampil**, dan kolom menampilkan aksi selanjutnya yang sesuai (Complete Submission, Assign Reviewers, atau aksi spesifik stage).

### 2. Workflow Page: Participants menampilkan editor yang ditugaskan
- **Sidebar** (`workflow.html.heex` lines 121–144) & **Panel Participants** (lines 415–426): sebelumnya hanya menampilkan author + `@user` (pengguna login). Kini mengiterasi `@submission.editors || []` sehingga **semua editor yang ditugaskan** tampil dengan label "Editor" (avatar biru, nama, role).

### File yang diubah
- `lib/ojs_landing_web/controllers/editor_html.ex` — `editorial_actions/1`: kondisi Assign Editor jadi `not row.has_editor`.
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — dua section Participants (sidebar + main content) menampilkan `@submission.editors`.
- `lib/ojs_landing_web/controllers/editor_controller.ex` — render workflow dengan `mode: :editor` (fix KeyError `@mode`).

### Status
- `mix precommit` lulus: 145 test, tanpa warning.
- `mix assets.build` sukses.

## Stepper wizard submission: perbaikan logika warna status step

Perbaikan pada stepper wizard submission (`/submission/wizard/:id?tab=...`) terkait penentuan
step mana yang tampil **hijau** (`is-done`) vs **biru** (`is-current`).

### Bug 1: step aktif (current) ikut berwarna hijau
- **Gejala:** step yang sedang dibuka (mis. Contributors) tampil hijau padahal masih aktif,
  tidak biru.
- **Penyebab:** template menambahkan class `is-done` ke semua step yang `wizard_step_done?`
  mengembalikan `true`, termasuk step yang sedang aktif. Karena CSS `is-done` didefinisikan
  setelah `is-current`, warna hijau menimpa biru.
- **Perbaikan:** di `edit_submission.html.heex`, class `is-done` kini hanya diterapkan bila step
  **bukan** tab aktif: `elem(tab, 0) != @current_tab && wizard_step_done?(...)`.

### Bug 2: step Review sudah hijau meski belum sampai ke sana
- **Gejala:** step Review tampil hijau padahal submission belum disubmit.
- **Penyebab:** `tab_done?("review", ...)` sebelumnya hanya mengecek apakah details + files +
  contributors sudah terisi data — artinya hijau begitu tiga step awal lengkap, tanpa menunggu
  submission benar-benar disubmit.
- **Perbaikan:** `tab_done?("review", ...)` kini memakai `submission.status != :incomplete`,
  sehingga hanya hijau setelah author menekan **Submit to Journal**.

### Bug 3: step For the Editor tetap abu meski sudah diisi
- **Gejala:** step For the Editor tidak pernah hijau walaupun komentar sudah diketik.
- **Penyebab:** `tab_done?("editors", ...)` salah memeriksa `length(submission.editors || []) > 0`
  — daftar editor yang diisi oleh **editor**, bukan field `editor_comments` yang diisi author
  di tab ini.
- **Perbaikan:** `tab_done?("editors", ...)` kini memeriksa `submission.editor_comments`.
  Catatan: komentar untuk editor bersifat opsional, sehingga step ini baru hijau jika komentar
  terisi (tidak akan hijau bila sengaja dikosongkan).

### File yang diubah
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — class `is-done`
  hanya untuk step non-aktif.
- `lib/ojs_landing_web/controllers/author_html.ex` — `tab_done?("review", ...)` berbasis
  `submission.status`; `tab_done?("editors", ...)` memakai `editor_comments`.

### Status
- `mix compile` bersih.

## Edit Contributor kini dibuka lewat Modal Window + tombol panah urutan contributor berfungsi

### "Edit Contributor" membuka Modal Window
Pada wizard submission (`/submission/wizard/:id?tab=contributors`), klik **Edit** pada baris
contributor sebelumnya membuka form edit **inline** di atas daftar (`view=edit&contributor_id=...`).
Kini form edit ditampilkan sebagai **Modal Window** (`#contributor-edit-modal`) berisi seluruh field
profil contributor (given name, family name, preferred public name, email, country, affiliation,
bio statement, role, primary contact, include in public list).

- Modal terbuka **otomatis** saat halaman dirender dengan `editing_contributor` (mengikuti
  parameter `view=edit`), lalu mem-focus field Given name.
- Form modal me-*submit* ke handler yang sama (`handle_contributor_edit/5` → PUT
  `/submission/wizard/:id?tab=contributors` dengan `submission[contributor_edit_id]` dan
  `submission[contributor_edit][...]`), lalu redirect kembali ke tab contributors.
- Modal dapat ditutup lewat tombol `×`, **Cancel**, klik area overlay, atau **Escape**; `body`
  diberi class `ojs-modal-open` untuk mengunci scroll.

### Perbaikan: tombol panah (↑/↓) urutan contributor dapat diklik
Pada mode order (`/submission/wizard/:id?tab=contributors&view=order`), tombol **↑/↓** sebelumnya
di-hardcode dengan atribut `disabled` sehingga tidak dapat diklik dan reorder tidak berfungsi.

Perbaikan: tombol panah kini menjadi form POST terpisah (masing-masing membawa
`submission[move_contributor_id]` dan `submission[move_dir]` = `up`/`down`) yang memanggil
`Submission.move_contributor/3` untuk menukar posisi contributor di daftar, lalu redirect kembali
ke mode order. Tombol **↑** dinonaktifkan pada contributor pertama dan **↓** pada contributor
terakhir (batas daftar).

### File yang diubah
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — form edit contributor
  dipindah dari inline card atas daftar menjadi modal `#contributor-edit-modal`; JS buka otomatis +
  tutup (close, cancel, overlay, Escape); tombol panah order menjadi form POST dengan
  `move_contributor_id`/`move_dir`.
- `lib/ojs_landing_web/controllers/author_controller.ex` — klausa dispatch baru
  `handle_contributor_move/4` di `update_submission/2` yang memanggil `Submission.move_contributor/3`
  lalu redirect ke `?tab=contributors&view=order`.
- `lib/ojs_landing/submission.ex` — fungsi baru `move_contributor/3` untuk menukar posisi
  contributor (dir `up`/`down`) dan menyimpannya ke store.
- `assets/css/app.css` — `.ojs-contributor-order form { display: flex; margin: 0 }` agar form
  pembungkus tombol tidak merusak layout tombol 30×30.

### Status
- `mix compile` bersih.
- `mix precommit` lolos (151 test, 0 failure).

## Add Contributor kini dibuka lewat Modal Window + perbaikan kontributor tertimpa

### "Add Contributor" membuka modal
Pada wizard submission (`/submission/wizard/:id?tab=contributors`), tombol **Add Contributor**
sebelumnya merupakan link navigasi yang membuka halaman edit contributor sebaris
(`view=edit&contributor_id=...`). Kini tombol tersebut menjadi `<button type="button">` yang
membuka **Modal Window** (`#contributor-modal`) berisi form tambahan contributor lengkap (given
name, family name, preferred public name, email, country, affiliation, bio statement, role,
primary contact, include in public list).

- Form modal me-*submit* ke handler yang sama (`handle_contributor_edit/5` → PUT
  `/submission/wizard/:id?tab=contributors` dengan `submission[contributor_edit_id]` dan
  `submission[contributor_edit][...]`), lalu redirect kembali ke tab contributors.
- Modal dapat ditutup lewat tombol `×`, tombol **Cancel**, klik area overlay, atau tombol
  **Escape**. `body` diberi class `ojs-modal-open` untuk mengunci scroll saat modal terbuka.
- `<.form>` di dalam modal tidak menggunakan `<.input>`, melainkan input biasa dengan
  `name="submission[contributor_edit][...]"` mengikuti pola form edit contributor yang sudah ada.

### Perbaikan: role contributor lain berubah saat menambah contributor
Gejala: ketika menambah contributor, contributor lain yang tadinya **author** ikut berubah menjadi
**translator**.

Akar masalah: saat submission **belum punya contributor tersimpan**, daftar menampilkan
contributor "default" (penulis yang sedang login) secara **virtual** — dengan **id sama dengan
`user.id`**. Contributo virtual ini tidak benar-benar tersimpan, sehingga:
1. Ketika satu contributor sungguhan ditambahkan, contributor default penulis itu **hilang/
   tergantikan** (karena daftar tersimpan menjadi tidak kosong).
2. Id contributor default (`user.id`) bisa **bentrok** dengan id contributor yang sudah ada, dan
   `Submission.update_contributor/3` mencocokkan berdasarkan id → contributor lama **ditimpa**
   (termasuk `role`-nya) alih-alih menambah yang baru.

Perbaikan di `AuthorController.handle_contributor_edit/5`: ditambahkan `ensure_default_contributor/2`
yang, jika submission belum punya contributor tersimpan, **mempatuhkan penulis yang sedang login
sebagai contributor primary (role author)** sebelum edit/add dijalankan. Hasilnya penulis utama
tetap author + primary dan tidak lagi hilang/berubah, sedangkan contributor baru ditambahkan
sebagai entri terpisah.

### File yang diubah
- `lib/ojs_landing_web/controllers/author_html/edit_submission.html.heex` — tombol Add Contributor
  menjadi `<button>` pembuka modal; markup modal `#contributor-modal` (form tambah contributor);
  JavaScript buka/tutup modal (tombol close, cancel, overlay, Escape).
- `lib/ojs_landing_web/controllers/author_controller.ex` — `ensure_default_contributor/2` dipanggil
  dari `handle_contributor_edit/5`.
- `assets/css/app.css` — style modal contributor (`ojs-modal-*`) dengan desain OJS 3.5 PKP
  (`--ojs-primary: #006798`, font Noto Serif), termasuk `.ojs-modal-overlay[hidden] { display: none }`
  agar atribut `hidden` tidak ditimpa oleh `display: flex`.

### Status
- `mix compile` bersih.
- Test `author_controller_test.exs` lolos (31 test, 0 failure).

## My Submissions: tombol "View" membuka workflow read-only untuk author

Tombol **View** pada `/dashboard/mySubmissions` sebelumnya membuka **editor workflow page**
(`/dashboard/editorial?workflowSubmissionId=...`) yang menampilkan panel editor (Action Panel,
Participants, tombol keputusan editorial). Kini author diarahkan ke halaman workflow **read-only**
khusus author di `/submission/:id/workflow` — tampilan serupa, tetapi tanpa akses mengedit dan
tanpa panel editor.

### Kolom STAGE & EDITORIAL ACTIVITY untuk submission belum selesai
- Kolom **STAGE** menampilkan **"Incomplete"** (dengan dot merah) untuk submission berstatus
  `:incomplete` (selain itu "Submission").
- Kolom **EDITORIAL ACTIVITY** menampilkan tautan **"Complete Submission"** yang mengarah ke wizard
  (`/submission/wizard/:id?tab=details`) untuk submission `:incomplete`.
- Kolom **ACTIONS** untuk submission `:incomplete` kini **kosong** (tombol **Continue** dihapus,
  karena "Complete Submission" sudah menjadi aksinya). Untuk submission lain tetap menampilkan
  **View**.

### Fitur workflow read-only author (`/submission/:id/workflow`)
- Route + action baru `AuthorController.author_workflow/2` merender template `workflow` editor
  dengan `mode: :author`.
- **Back to Submissions** mengarah ke `/dashboard/mySubmissions` (bukan editorial dashboard).
- Menu **Workflow** & **Publication** menggunakan URL author (`/submission/:id/workflow`).
- **Sembunyikan** untuk author:
  - Panel **Participants** (sidebar) dan panel **Action Panel** (workflow_1).
  - Tombol keputusan editorial: Send For Review / Accept & Skip Review / Decline (workflow_1),
    Request Revisions / Accept / Decline (workflow_3_1), Accept & Schedule / Decline (workflow_5).
  - Tautan "Manage copyediting" (workflow_4) dan "Open production record" (workflow_5).
- Form publikasi (Title & Abstract, Metadata, References) dirender **read-only** (`disabled`/
  `readonly`) tanpa tombol Save — author hanya melihat, tidak bisa mengedit.
- Navigasi Previous/Next submission tidak ditampilkan untuk author.
- Status readonly juga disajikan lewat message "Editorial decisions are managed by the journal's
  editors" pada stage review.

### File yang diubah
- `lib/ojs_landing_web/router.ex` — route baru `get "/submission/:id/workflow"`.
- `lib/ojs_landing_web/controllers/author_controller.ex` — action `author_workflow/2` (render
  `EditorHTML.workflow` dengan `mode: :author`, `put_view` + `render/3`); helpers
  `author_review_assignments/1`, `author_to_row/1`, `normalize_menu/1`, `title_or_placeholder/1`,
  `days_since/1`; menu `@workflow_menus`, `@publication_menus`, `@default_menu`.
- `lib/ojs_landing_web/controllers/author_html.ex` — `submission_workflow_path/2` kini menunjuk
  `/submission/:id/workflow?workflowMenuKey=...` (bukan editorial dashboard).
- `lib/ojs_landing_web/controllers/author_html/my_submissions.html.heex` — STAGE "Incomplete",
  EDITORIAL ACTIVITY "Complete Submission", ACTIONS kosong untuk `:incomplete`.
- `lib/ojs_landing_web/controllers/editor_html.ex` — helper `wf_menu_href/4` (URL author vs
  editor).
- `lib/ojs_landing_web/controllers/editor_html/workflow.html.heex` — kondisi `@mode == :author`
  untuk back-link, menu, sembunyikan panel editor & tombol keputusan, form publikasi readonly.

### Status
- `mix compile --warnings-as-errors` bersih.
- `mix precommit` lulus: 151 test, tanpa warning.

## Save for Later: halaman konfirmasi "Saved for Later"

Mengklik **Save for Later** pada wizard submission (`/submission/wizard/:id?tab=...`) atau
halaman `/submission/:id/details` tidak lagi langsung mengarahkan ke My Submissions, melainkan
menampilkan **halaman konfirmasi** di `/submission/wizard/:id/saved`.

### Fitur
- Halaman konfirmasi menampilkan judul **Saved for Later** di tengah dan sebuah kotak berisi
  teks *"Your submission details have been saved in our system. You can return to complete your
  submission at any time by following the link below."*.
- Di dalam kotak terdapat tautan berisi **nama author — judul submission** (tanpa username).
  Mengkliknya akan kembali ke wizard pada **langkah pertama yang belum selesai**
  (`?tab=first_incomplete_tab`), sehingga author dapat melanjutkan progres submission-nya.
- Tidak ada ikon centang hijau maupun tombol aksi tambahan pada halaman konfirmasi.

### File yang diubah
- `lib/ojs_landing_web/controllers/author_controller.ex` — `handle_generic_update/5` dan
  `save_details/2` kini redirect ke `/submission/wizard/:id/saved` saat save for later
  (`action=save` atau `save_status=draft`, sebelumnya redirect ke My Submissions);
  `saved_submission/2` dirender sebagai halaman (bukan sekadar redirect flash);
  helper baru `author_display_name/2` (nama tanpa username) dan `first_incomplete_tab/1`.
- `lib/ojs_landing_web/controllers/author_html/saved_submission.html.heex` (baru) — template
  halaman konfirmasi.
- `assets/css/app.css` — gaya `.ojs-saved-*` (card terpusat, kotak teks, tautan resume).
- `test/ojs_landing_web/controllers/author_controller_test.exs` — test disesuaikan: save for
  later mengarah ke `/submission/wizard/:id/saved`; test halaman konfirmasi dirender.

### Status
- `mix precommit` lulus: 151 test, tanpa warning.
- `mix assets.build` sukses (perlu hard-refresh Ctrl+F5).

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

> **Diperbarui:** Perilaku ini kini digantikan oleh halaman workflow **read-only author**
> (`/submission/:id/workflow`) — lihat entri *"My Submissions: tombol "View" membuka workflow
> read-only untuk author"* di bagian atas. Pemetaan menu per stage di bawah tetap relevan.

Tombol **View** pada `/dashboard/mySubmissions` tidak lagi membuka wizard submission
(`/submission/wizard/:id?tab=...`), melainkan membuka workflow page sesuai stage submission.

- Stage `initial_review`/belum review → `workflow_1` (Submission).
- Stage review (`external_review`, `needs_reviews`, `awaiting_reviews`, `reviews_submitted`,
  `revisions_submitted`) → `workflow_3_1` (External Review).
- Stage `copyediting` → `workflow_4`.
- Stage `production` → `workflow_5`.
- Submission status `:incomplete` tidak menampilkan tombol View di kolom Actions (kolom kosong);
  aksinya adalah "Complete Submission" di kolom EDITORIAL ACTIVITY.

### File yang diubah
- `lib/ojs_landing_web/controllers/author_html.ex` — helper `submission_workflow_path/2` (URL
  workflow + `workflow_menu_for_stage/1` meniru `default_workflow_menu_for_stage` editor).
- `lib/ojs_landing_web/controllers/author_html/my_submissions.html.heex` — link View memakai
  `submission_workflow_path/2`; STAGE "Incomplete", "Complete Submission", Actions kosong untuk
  `:incomplete`.

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
