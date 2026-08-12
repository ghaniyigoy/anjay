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
* **Jurnal** — Halaman jurnal, current issue, arsip, daftar isu, halaman about (submissions, editorial masthead, privacy, contact), dan halaman detail artikel
* **Journal Submission Workflow** — Halaman submission per-jurnal dengan tab Details, Files, Contributors, Editors, dan Review (`/:journal_path/submission?id=X#tab`)
* **Submissions** — Wizard & manajemen submission untuk author
* **Editorial** — Workflow editorial untuk editor
* **Review** — Pengelolaan penugasan review untuk reviewer
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

### Author Submission (membutuhkan login)

Membuat & mengelola submission membutuhkan login sebagai **author**; bila belum login akan dialihkan ke `/login`.

| URL | Method | Keterangan |
| --- | --- | --- |
| `/dashboard/mySubmissions` | GET | Daftar submission author (dengan filter status) |
| `/submission/new` | GET | Mulai submission baru (preliminary information, wizard ala OJS 3 PKP) |
| `/submission/create` | POST | Buat submission baru, lalu redirect ke wizard |
| `/submission/wizard` | GET/POST | Alias dari `/submission/new` & `/submission/create` |
| `/submission/wizard/:id?tab=details` | GET/PUT | Wizard detail submission (tab: details, files, contributors, editors, review) |

Contoh: `http://localhost:4000/submission/new`

## Struktur

* `lib/ojs_landing/` — context & domain logic (user, journal, submission)
* `lib/ojs_landing_web/` — controllers, plugs, layouts, dan templates
* `assets/` — Tailwind CSS & JavaScript

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix