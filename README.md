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
* **Jurnal** — Halaman jurnal, current issue, arsip, daftar isu, dan halaman about (submissions, editorial masthead, privacy, contact)
* **Submissions** — Wizard & manajemen submission untuk author
* **Editorial** — Workflow editorial untuk editor
* **Review** — Pengelolaan penugasan review untuk reviewer
* **Administrasi** — Konteks, pengaturan, sistem info, manajemen jurnal, jobs/failed jobs

## Routing

Global Auth Routes tersedia di root (`/login`, `/register`, `/logout`) maupun per-journal (`/:journal_path/login`, dst).

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