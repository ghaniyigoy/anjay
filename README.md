# OjsLanding

Aplikasi web **Open Journal Systems (OJS)** clone yang dibangun dengan [Phoenix Framework](https://www.phoenixframework.org/).

## Menjalankan Server

* Install dan setup dependencies dengan `mix setup`
* Jalankan Phoenix endpoint dengan `mix phx.server` atau di dalam IEx dengan `iex -S mix phx.server`
* Buka [`localhost:4000`](http://localhost:4000) di browser

## Akun Seed (Login)

Username `alief` adalah admin, sisanya seeded user:

| Username | Email | Password | Role |
| --- | --- | --- | --- |
| alief | alief@admin.com | password123 | admin |
| author1 | author1@informatika.ac.id | password123 | author |
| author | author@test.com | password123 | author |
| reviewer | reviewer@test.com | password123 | reviewer |
| editor | editor@test.com | password123 | editor |

## Fitur

* **Autentikasi** — Login, register, logout, dan profil pengguna
* **Dashboard** — Arahkan pengguna berdasarkan role (admin, author, editor, reviewer)
* **Jurnal** — Halaman jurnal, current issue, arsip, daftar isu, halaman about (submissions, editorial masthead, privacy, contact), halaman detail artikel
* **Journal Submission Workflow** — Halaman submission per-jurnal dengan tab Details, Files, Contributors, Editors, dan Review (`/:journal_path/submission?id=X#tab`)
* **Submissions** — Wizard & manajemen submission untuk author (details, files, contributors, editors, review) dengan tampilan flat OJS PKP di dalam dashboard
* **Editorial** — Workflow editorial untuk editor
* **Review** — Pengelolaan penugasan review untuk reviewer, termasuk halaman detail review per-assignment (`/review/:id`) dengan form kriteria & rekomendasi
* **Journal Settings** — Pengaturan jurnal bergaya OJS PKP (Journal, Website, Workflow, Distribution, Users & Roles), dapat diakses oleh **admin & editor**
* **Manage Issues** — Manajemen terbitan (issues) jurnal per volume/nomor dengan tab OJS PKP 3.5 (Future | Back Issues), tiap baris punya panah biru untuk membuka aksi (Edit, Preview, Publish/Unpublish)
* **Manage DOIs** — Halaman manajemen DOI bergaya OJS PKP 3.5 (grid editorial dengan tab Articles | Issues | Galleys, filter status, checkbox, dan panah biru untuk aksi per-baris), dapat diakses oleh admin & editor
* **DOI Artikel** — Halaman pendaftaran DOI untuk artikel bergaya OJS PKP 3.5 (sidebar Dasbor Editor dengan submenu DOI, bilah peringatan prefiks, filter Status & Pendaftaran, daftar artikel dengan checkbox & dropdown publikasi), dapat diakses oleh admin & editor
* **Administrasi** — Konteks, pengaturan, sistem info, manajemen jurnal, jobs/failed jobs

## Routing

Global Auth Routes tersedia di root (`/login`, `/register`, `/logout`) maupun per-journal (`/:journal_path/login`, dst).

### Journal Submission Workflow

| URL | Keterangan |
| --- | --- |
| `/:journal_path/submission` | Halaman workflow submission (default ke submission pertama) |
| `/:journal_path/submission?id=8` | Tampilkan submission dengan ID 8 |
| `/:journal_path/submission?id=8#details` | Tab Details (metadata makalah) |
| `/:journal_path/submission?id=8#files` | Tab Files (naskah & berkas pendukung) |
| `/:journal_path/submission?id=8#contributors` | Tab Contributors (penulis) |
| `/:journal_path/submission?id=8#editors` | Tab Editors (editor penanganan) |
| `/:journal_path/submission?id=8#review` | Tab Review (round, keputusan editor, assignment reviewer) |

Contoh: `http://localhost:4000/informatika/submission?id=8#review`

### Article View

| URL | Keterangan |
| --- | --- |
| `/:journal_path/article/:article_id` | Halaman detail artikel berdasarkan ID |
| `/:journal_path/article/view` | Alias yang menampilkan artikel pertama dari jurnal |

Contoh: `http://localhost:4000/JPD/article/1` atau `http://localhost:4000/JPD/article/view`

### Manage DOIs (admin & editor)

Halaman manajemen DOI bergaya OJS PKP 3.5. Dapat diakses oleh akun **`admin`** dan **`editor`**; pengguna lain atau yang belum login akan dialihkan ke `/login`.

**Navigasi:** item **DOIs** di sidebar dashboard editor atau tombol **DOIs** di dashboard admin.

Jalur lengkap: `/:journal_path/dois`.

Contoh: `http://localhost:4000/informatika/dois`

**Tampilan halaman:**
- Breadcrumb `Dashboard / DOIs` + judul & subtitle.
- Tab bergaya OJS: **Articles | Issues | Galleys** dengan jumlah item (hash-based).
- Sidebar filter kiri: grup **Status** (All, Needs DOI, DOI Assigned, Registered, Unregistered, Submitted, Error, Stale) dan dropdown **Issue**.
- List panel: kotak centang seleksi, tombol **Bulk Actions**, kotak pencarian, dan tabel dengan kolom checkbox, panah biru (expand aksi per-baris), Title, DOI, Status.

Data DOI diambil dari artikel jurnal (`Journal.all/0`, field `doi`) dan issue (`Issue.for_journal/1`).

### DOI Artikel Registration (admin & editor)

Halaman pendaftaran DOI khusus artikel bergaya OJS PKP 3.5. Dapat diakses oleh akun **`admin`** dan **`editor`**; pengguna lain atau yang belum login akan dialihkan ke `/login`.

**Navigasi:** halaman `Editorial` di dashboard editor → submenu **DOI → Artikel**, atau langsung melalui URL di bawah.

Jalur lengkap: `/dashboard/doiArticles`.

Contoh: `http://localhost:4000/dashboard/doiArticles`

**Tampilan halaman:**
- Bilah navigasi biru tua (judul jurnal, ikon info, lonceng notifikasi dengan badge, inisial pengguna).
- Sidebar putih **Dasbor Editor** → **Terbitan** → **DOI** (disorot biru muda) dengan submenu **Pengaturan | Statistik | Perangkat | Administrasi** (masing-masing berikon).
- Bilah peringatan oranye: *"DOI tidak dapat dibuat kecuali jika anda menyediakan prefiks DOI yang dibuat. Tambahkan prefiks DOI."*
- Header tab **Artikel** + judul bagian **Artikel**.
- Bilah alat: tab **DOI Artikel**, kotak pencarian **Cari**, tombol **Tindakan Massal**.
- Sidebar filter: **Status** (Membutuhkan DOI, DOI Ditetapkan) dan **Pendaftaran** (Tidak terdaftar, Dikirimkan, Didaftarkan, Terdapat Eror, Membutuhkan Sinkronisasi), plus **Terbitan** (kotak teks kecil).
- Tabel artikel dengan checkbox, judul, badge ID, dan dropdown publikasi (Diterbitkan / Tidak Diterbitkan).

Data artikel DOI bersifat dummy/presentasional di `DoiArticleController.get_articles/0`.

### Review Assignment (membutuhkan login reviewer)

Halaman detail penugasan review untuk reviewer dengan workflow bergaya OJS: stage bar (Submission → Review → Decision), kriteria penilaian, dan form rekomendasi. Membutuhkan login; pengguna lain atau yang belum login dialihkan ke `/login`.

| URL | Method | Keterangan |
| --- | --- | --- |
| `/dashboard/reviewAssignments` | GET | Daftar penugasan review reviewer (dengan filter status) |
| `/review/:id` | GET | Halaman detail review assignment ID tertentu |
| `/review/:id` | POST | Submit review (rekomendasi), lalu redirect kembali ke halaman review |

Contoh: `http://localhost:4000/review/1`

### Journal Settings (admin & editor)

Halaman pengaturan jurnal bergaya OJS PKP. Dapat diakses oleh akun **`admin`** dan **`editor`**; pengguna lain atau yang belum login akan dialihkan ke `/login`.

**Navigasi:**
- Dari **dashboard admin** (`/admin`): kartu "Journal Settings" berisi tombol **Open Journal Settings** dan **Manage Issues**.
- Dari **dashboard editorial editor** (`/dashboard/editorial`): sidebar berisi link **Issues** (langsung menuju Manage Issues) dan menu **Settings** yang berisi link ke tiap grup (Journal, Website, Workflow, Distribution, Users & Roles).

**Tampilan halaman:**
- Tab bar atas untuk berpindah antar grup (Journal | Website | Workflow | Distribution | Users & Roles).
- Sidebar kiri hanya menampilkan sub-menu grup aktif (seperti Masthead, Contact, dll. untuk Journal), dapat di-collapse/expand.
- Tombol Save & Cancel pada save bar sticky di bawah.

Jalur lengkap: `/:journal_path/management/settings/{section}#{sub-tab}`.

| URL | Section | Sub-tab |
| --- | --- | --- |
| `/management/settings/context` | Journal | `#masthead`, `#contact`, `#sections`, `#categories` |
| `/management/settings/website` | Website | `#setup`, `#plugins` |
| `/management/settings/workflow` | Workflow | `#submission`, `#review`, `#library`, `#emails` |
| `/management/settings/distribution` | Distribution | `#license`, `#dois`, `#indexing`, `#payments`, `#access`, `#archive` |
| `/management/settings/access` | Users & Roles | `#users`, `#roles`, `#access`, `#orcidSettings` |
| `/management/settings` | - | Redirect ke `/management/settings/context` |

Contoh: `http://localhost:4000/informatika/management/settings/distribution#dois`

### Manage Issues (admin & editor)

Halaman manajemen terbitan jurnal bergaya OJS PKP 3.5 dengan **tab ala OJS** (Future Issues | Back Issues), setiap baris terbitan memiliki **panah biru** yang bisa diklik untuk membuka menu aksi (Edit, Preview, Publish/Unpublish). Dapat diakses oleh akun **`admin`** dan **`editor`**; pengguna lain atau yang belum login akan dialihkan ke `/login`. Data terbitan diambil dari modul `OjsLanding.Issue`.

**Navigasi:** item **Issues** di sidebar dashboard editor (link langsung) atau tombol **Manage Issues** di dashboard admin.

Jalur lengkap: `/:journal_path/manageIssues`.

Contoh: `http://localhost:4000/informatika/manageIssues`

**Navigasi tab** (hash-based):

| Tab | Anchor | Isi |
| --- | --- | --- |
| Future Issues | `#future` | Terbitan belum dipublikasi (Scheduled/Unpublished), dengan aksi Edit, Preview, Delete |
| Back Issues | `#back-issues` | Semua terbitan yang sudah dipublikasi, dengan aksi View (menuju halaman issue), Edit, Unpublish |

Setiap baris terbitan:

| Elemen | Keterangan |
| --- | --- |
| Panah biru | Diklik untuk membuka/menutup menu aksi terbitan (Edit, Preview, Publish/Unpublish) |
| Issue | Label volume/nomor, mis. `Vol. 1, No. 1 (2024)` + judul |
| Articles | Jumlah artikel pada terbitan |
| Actions | Aksi View (menuju halaman issue), Edit, Delete / Unpublish |

### Author Submission (membutuhkan login)

Membuat & mengelola submission membutuhkan login sebagai **author**; bila belum login akan dialihkan ke `/login`.

| URL | Method | Keterangan |
| --- | --- | --- |
| `/dashboard/mySubmissions` | GET | Daftar submission author (dengan filter status) |
| `/submission/new` | GET | Mulai submission baru (preliminary information, wizard ala OJS 3 PKP) |
| `/submission/create` | POST | Buat submission baru, lalu redirect ke wizard |
| `/submission/wizard` | GET/POST | Alias dari `/submission/new` & `/submission/create` |
| `/submission/wizard/:id?tab=details` | GET/PUT | Wizard detail submission (tab: details, files, contributors, editors, review), dirender di dalam layout dashboard |

Submission seed aktif untuk author1: ID `14` (`/submission/wizard/14?tab=details`, status *Active*).

Contoh: `http://localhost:4000/submission/new`

## Struktur

* `lib/ojs_landing/` — context & domain logic (user, journal, submission, issue)
* `lib/ojs_landing_web/` — controllers, plugs, layouts, dan templates
* `assets/` — Tailwind CSS & JavaScript

## Reviewer Review (referensi)

* `lib/ojs_landing_web/controllers/reviewer_controller.ex` — `review/2` (halaman detail) & `submit_review/2` (post rekomendasi), plus data assignment dummy (round, files, review history)
* `lib/ojs_landing_web/controllers/reviewer_html/review.html.heex` — template detail review (stage bar, kriteria, form rekomendasi)
* `lib/ojs_landing_web/plugs/auth.ex` — guard `:require_editor_admin` untuk akses admin/editor

## Admin Settings (referensi)

* `lib/ojs_landing_web/controllers/settings_controller.ex` — guard akses admin + render per section, termasuk `manage_issues/2` dan `dois/2`
* `lib/ojs_landing_web/controllers/settings_html.ex` — layout & komponen form Settings, plus helper issue (badge status, label volume/nomor, `issue_groups/1`) dan helper DOI (`doi_status_text/1`, `doi_status_class/1`, `doi_status_badge/1`)
* `lib/ojs_landing_web/controllers/settings_html/` — template per section (context, website, workflow, distribution, access) + `manage_issues.html.heex` + `dois.html.heex`
* `lib/ojs_landing/issue.ex` — modul Issue dengan data seed (per volume/nomor, status, daftar artikel)
* `assets/css/app.css` — gaya `.settings-*` (tabs, panel, tabel, save bar) + `.settings-status.is-published/.is-scheduled` + `.manage-issues-*`

## DOI Artikel Registration (referensi)

* `lib/ojs_landing_web/controllers/doi_article_controller.ex` — guard akses admin/editor + render data artikel DOI dummy (status, counts, publikasi)
* `lib/ojs_landing_web/controllers/doi_article_html.ex` — view module untuk template DOI Artikel
* `lib/ojs_landing_web/controllers/doi_article_html/index.html.heex` — template halaman (sidebar Dasbor Editor, bilah peringatan, tab Artikel, filter Status/Pendaftaran/Terbitan, tabel artikel)
* `lib/ojs_landing_web/components/layouts/dashboard.html.heex` — layout dashboard (header biru tua dengan judul jurnal, ikon info, lonceng notifikasi, inisial pengguna)
* `test/ojs_landing_web/controllers/doi_article_controller_test.exs` — test akses & konten halaman

## Referensi Teknis

Arsitektur aplikasi untuk pengembang yang ingin memahami atau memperluas kode.

### Arsitektur & penyimpanan data

Aplikasi **tidak menggunakan database (Ecto/PostgreSQL)**. Semua data bersifat *in-memory*:

* **`OjsLanding.User`** — `Agent` berisi data user ter-seed; registrasi baru disimpan dalam proses (`Agent.update/2`) sehingga bertahan antar request selama server hidup.
* **`OjsLanding.Submission`** — `Agent` berisi submission ter-seed; `create/2`, `update/2`, dan `set_status/3` menyimpan ke dalam proses.
* **`OjsLanding.Journal`** — *plain struct* dengan daftar statis (`Journal.all/0`), berisi artikel per jurnal.
* **`OjsLanding.Issue`** — *plain struct* terbitan (volume/nomor/status) dengan data statis.

Konsekuensi: setiap *restart server* mengembalikan data ke kondisi seed.

### Struktur modul

| Modul | Jenis | Tanggung jawab |
| --- | --- | --- |
| `OjsLanding.User` | Agent | User & autentikasi (`find_by_username/1`, `verify_login/2`, `register/1`) |
| `OjsLanding.Submission` | Agent | Submission author (`get_by_author/1`, `create/2`, `update/2`) |
| `OjsLanding.Journal` | struct | Data jurnal & artikel statis (`all/0`, `get!/1`) |
| `OjsLanding.Issue` | struct | Data terbitan statis (`all/0`, `for_journal/1`, `current/1`) |
| `OjsLanding.Application` | OTP app | Supervisor tree; memulai `User` & `Submission` sebelum endpoint |

### Lapisan web (`lib/ojs_landing_web/`)

* **`router.ex`** — tiga `scope` utama: root (`/`), admin (`/admin`), dan per-journal (`/:journal_path`). Semua melewati pipeline `:browser` yang memuat `OjsLandingWeb.Plugs.Auth`.
* **`plugs/auth.ex`** — tiga guard: default (set `current_user` dari session), `:require_admin`, dan `:require_editor_admin` (admin **atau** editor, selain itu redirect ke `/login`).
* **`components/layouts.ex`** — `Layouts` (root, dashboard, admin, journal). Dashboard dipakai halaman editor/admin dengan header biru tua.
* **`components/core_components.ex`** — komponen UI bawaan Phoenix (`<.input>`, `<.icon>`, `<.flash>`, dll).
* **`controllers/*_html.ex`** — view module per fitur; template di-*embed* dari folder `*_html/`.
* **`controllers/settings_html.ex`** — helper bersama: `doi_status_badge/1`, `issue_groups/1`, komponen form OJS PKP (`input_field`, `select_field`, dsb).

### Alur autentikasi

`Plugs.Auth.call/2` default membaca session `current_user`, lalu `assign(conn, :current_user, user)` atau `nil`. Controller dengan `plug OjsLandingWeb.Plugs.Auth, :require_editor_admin` akan memblokir user non-admin/editor. Login/register disediakan di root (`/login`, `/register`) dan per-journal.

### Aset & styling

* **Tailwind CSS v4** (tanpa `tailwind.config.js`) — file sumber `assets/css/app.css` berisi `@import "tailwindcss" source(none)` + direktif `@source`.
* CSS kustom (gaya OJS PKP) ditulis langsung sebagai aturan CSS polos di `assets/css/app.css` (bukan `@apply`).
* Build: `tailwind` menghasilkan `priv/static/assets/css/app.css`, `esbuild` menghasilkan `priv/static/assets/js/app.js`.
* Untuk mem-build ulang aset secara manual: `mix assets.build` (dev) atau `mix assets.deploy` (produksi, minified + digest).

### Perintah Mix

| Alias | Isi |
| --- | --- |
| `mix setup` | `deps.get` + `assets.setup` + `assets.build` |
| `mix assets.setup` | Install Tailwind & esbuild |
| `mix assets.build` | `compile` + `tailwind` + `esbuild` (tidak minify) |
| `mix assets.deploy` | `tailwind --minify` + `esbuild --minify` + `phx.digest` |
| `mix precommit` | `compile --warnings-as-errors` + `deps.unlock --unused` + `format` + `test` |

`mix precommit` dijalankan dalam env `:test` (lihat `cli/0` di `mix.exs`).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix