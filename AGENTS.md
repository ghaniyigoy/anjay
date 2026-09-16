This is a web application written using the Phoenix web framework.

## Environment & dev workflow (Windows + WSL)

- The dev server (`mix phx.server`) runs **inside WSL (Ubuntu)** against `/mnt/c/Users/HP/Documents/anjay`, serving `http://localhost:4000`
- **WSL2 localhost forwarding**: `~/.wslconfig` must exist with `[wsl2] localhostForwarding=true` for Windows to reach the server. After creating/editing this file, run `wsl --shutdown` and restart WSL
- **Run all mix commands (compile, test, `mix precommit`) from WSL**, not from Windows PowerShell — the running WSL server holds locks on the shared `_build` folder and Windows-side compiles fail with `(File.Error) could not remove files ... file already exists`:

      wsl -d Ubuntu --cd /mnt/c/Users/HP/Documents/anjay -- bash -lc "mix precommit"

- If CSS changes are not picked up by the tailwind watcher, rebuild assets from WSL (`wsl -d Ubuntu --cd /mnt/c/Users/HP/Documents/anjay -- bash -lc "mix assets.build"`) and hard-refresh the browser (Ctrl+F5)
- To restart the server from an agent tool session, spawn the process detached via WMI so it survives the session ending:

      Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = 'wsl.exe -d Ubuntu --cd /mnt/c/Users/HP/Documents/anjay -- bash -lc "exec mix phx.server"'
      }

- Data lives in **in-memory Agent stores** (`OjsLanding.Submission`, `OjsLanding.User`, `OjsLanding.ReviewerAssignment`) and resets whenever the server restarts
  - Seeded submissions use IDs 5–14 (authors: author1 = Ahmad Fauzi, etc.)
  - Seeded reviewer assignments use IDs 1–6 (statuses: action_required, in_progress, completed, published, declined)
  - Test logins (all password `password123`): `author1@informatika.ac.id` (author), `editor@test.com` (editor), `alief@admin.com` (admin), `reviewer@test.com` (reviewer)
- Submission model fields include: `stage` (submission/initial_review/external_review/copyediting/production), `checklist_agreed`, `privacy_consent`, `comments_to_editor`, `section`, `language`
- Author submission wizard: `/submission/wizard/:id?tab=details|files|contributors|editors|review` (controller-driven, `AuthorController`). "Submit to Journal" sets status `:active` and stage `:initial_review`, which makes the submission appear in the editor dashboard `/dashboard/editorial`
  - Wizard **Continue** buttons are real form submits (`name="action" value="continue"`); `AuthorController.handle_generic_update/5` saves and redirects to the next tab (details→files→contributors→editors→review). Details Continue requires a non-blank title + abstract, otherwise it redirects back with an error flash
  - Uploaded files exist client-side only until the files form is submitted; inline JS in `edit_submission.html.heex` serializes the `.ojs-file-item` rows into the hidden `submission[files_json]` input (JSON), and `OjsLanding.Submission.update/2` parses it into normalized `%{id:, filename:, size:, date:, genre:}` maps. Files/contributors are never persisted by merely navigating between tabs — the form must be submitted (Continue or Save for Later)
  - Contributors tab Primary Contact UI: the primary-contact contributor shows a `ojs-chip` "Primary Contact" badge; every other contributor shows a boxed "Set Primary Contact" button (class `ojs-set-primary-btn`, white background with blue `var(--ojs-primary)` text via `assets/css/app.css`). Clicking sets that contributor as primary and clears the flag from the others. In the **controller-driven** template (`edit_submission.html.heex`) the button is a real form POSTing to `POST /submission/wizard/:id/set-primary-contact` (`AuthorController.set_primary_contact/2` → `Submission.set_primary_contact/2`, which sets `primary: true` on the target and `primary: false` on all others, then redirects back to the contributors tab). In the **LiveView** wizard (`submission_wizard_live.ex` `contributors_step/1`) the equivalent button uses `phx-click="set_primary_contact"` (`SubmissionWizardLive.handle_event/3`) which updates `contributors`/`primary_contact_id` client-side without a page reload. Note: the URL `/submission/wizard/:id?tab=contributors` is served by the controller route (`get "/submission/wizard/:id"`), while the LiveView lives at `/submission/:id/wizard/:step` — both render the same contributors UI
  - Rich-text fields (abstract, editor comments) are contenteditable divs synced into their hidden inputs on form submit (see `assets/js/app.js`)
- New submission form (`/submission/new`): Section picker (Artikel Penelitian, Tinjauan Literatur, Studi Kasus, Laporan Teknis, Forum), Language picker (Bahasa Indonesia, English), Submission Checklist agreement (required), Privacy Consent (required), Comments to the Editor (optional). Title + checklist + privacy are validated client-side and server-side before creating
- Bare `/submission/:id` (`AuthorController.show/2`) redirects logged-in users to `/submission/wizard/:id?tab=details`; unknown ids flash an error and redirect to My Submissions
- Author submissions dashboard `/dashboard/mySubmissions`: shows author's submissions table with sidebar filters, ACTIONS column has a "View" button (`.btn-view` class) styled as a white-text button on blue background via `.author-main-content .submissions-table .btn-view { color: #fff !important; }` in `assets/css/app.css`
- Editor dashboard `/dashboard/editorial`: the author column shows the submission's contributor name (primary contact first, then any listed contributor), falling back to the account name from `OjsLanding.User` only when the submission has no contributors (`EditorController.author_name/1`)
  - **Actions column**: each row has a plain-text "View" link (class `editorial-view-link`, no button styling) linking to the workflow page via `workflow_menu_path/3` using the stage-appropriate menu key
  - **Editorial Activity column**: shows contextual action links based on submission state — "Assign Editor" if no editor assigned (checked first, regardless of stage, because review/editorial decisions cannot begin until an editor handles the submission), "Complete Submission" if incomplete/not yet submitted, "Assign Reviewers" if no reviewer assignments exist, or no action otherwise (`EditorHTML.editorial_actions/1` — for `initial_review` when reviewers already exist, Editorial Activity shows no action link). Data flows through `to_editorial_row/1` which enriches each row with `has_editor`, `has_reviewers`, and `needs_submission_complete` flags derived from `Submission.editors` and `ReviewerAssignment` matches by title
  - **Assign Reviewers drawer**: when "Assign Reviewers" is clicked (`EditorHTML.editorial_actions/1` returns `%{modal: "assign-reviewers-#{row.id}"}`), it opens an **Add Reviewer Page** slide-in drawer (`.ar-overlay`/`.ar-panel` CSS, same right slide-in pattern as the `workflow_3_1` Add Reviewer drawer in `editorial.html.heex`): blue `#006798` header with back-arrow + centered "Add Reviewer", a **Submission Author List** box showing `username - affiliation` (from the submission's primary contact contributor via `EditorController.author_username/1` + `author_affiliation/1`, exposed in `@ap_submissions_json`), a **Locate a Reviewer** row with a live Search box (`#ar-search-input`, `oninput="arFilterReviewers()"`) and a **Filters** button (toggles the `#ar-filters-sidebar` with rated/completed/days/active/avg filter options), and a reviewer card list (`#ar-reviewer-list`) rendered **client-side** into `.ar-reviewer-card` elements from `window.__arReviewers` (`@ap_users_json`, all users via `reviewer_json/1`, filtered to reviewer/editor roles). Each card shows username, affiliation, and Review Count/Last Review/Status stats; **Select Reviewer** (`selectArReviewer/1`) sets the hidden `#assign-reviewer-form` `reviewer_name` and POSTs to `/dashboard/editorial/:id/assign-reviewer` (`EditorController.assign_reviewer/2`). Footer has placeholder **Create New Reviewer** / **Enroll Existing User** buttons; open via `openAddReviewerModal(submissionId)` which toggles class `ar-open` and closes via back-arrow, backdrop, or Escape (reuses the global `ar*` helpers in `assets/js/app.js`)
  - **Assign Editor drawer**: when "Assign Editor" is clicked (no editor assigned yet), `EditorHTML.editorial_actions/1` returns `%{modal: "assign-editor-#{row.id}"}` which triggers a client-side drawer instead of navigating. The drawer (`#assign-editor-overlay` in `editorial.html.heex`) is a **right slide-in Assign Participant page** (`.apd-*` CSS — same pattern as the `workflow_1` Assign Participant drawer, overlay `justify-content: flex-end`, panel `translateX(100%) → 0`, width `720px`): blue `#006798` header with back-arrow + centered "Assign Participant", a **Locate a User** heading with a role dropdown (`#ap-role-filter`: Journal Editor / Section Editor / Guest Editor / Funding coordinator / Author / Translator) beside a search box (`#ap-search-name`), below it a **"Search User By Name"** heading (`.apd-search-heading`) over a **user table** (Name, Assignments, Affiliation, Reviewing Interest columns) rendered client-side into `#ap-users-tbody` from `window.__apUsers`, plus a Message section with predefined message dropdown + rich text editor (bold/italic/underline/bullet) and a Cancel/Send footer. User data is pre-encoded as JSON (`@ap_users_json` via `Jason.encode!`) in the controller and filtered client-side (`filterAssignEditorUsers()`), selecting a row adds `.apd-user-selected`. On submit, the hidden form POSTs to `POST /dashboard/editorial/assign-editor` (`EditorController.assign_editor/2`) which calls `Submission.assign_editor/2` to append the editor to the submission's `editors` list. Opened via `openAssignEditorModal(submissionId)` which toggles class `apd-open` (close via back-arrow, Cancel, backdrop, or Escape)
- Editor workflow view (OJS PKP 3.5 style): `/dashboard/editorial?workflowSubmissionId=<id>&currentViewId=<view>&workflowMenuKey=<key>` opens a single submission's workflow page (`editor_html/workflow.html.heex`) instead of the submissions table
  - Workflow menu keys: `workflow_1` (Submission: two-column layout with Submission Files + Pre-Review Discussions on the left, Action Panel + Participants on the right), `workflow_3_1` (External Review round 1 — review assignments matched to the submission by title), `workflow_4` (Copyediting tasks), `workflow_5` (Production: galleys/proofreading). The `workflow_1` **Participants card Assign button** (`#btn-assign-participant`, `onclick="openAssignParticipantDrawer()"`) opens a right slide-in **Assign Participant drawer** (`#assign-participant-drawer`, `.apd-*` CSS, mirroring the `.ar-overlay`/`.urf-overlay` slide pattern, panel width `720px`): blue `#006798` header with back-arrow + "Assign Participant", a **Locate a User** row with a role dropdown (`#apd-role-filter`: Journal Editor / Section Editor / Guest Editor / Finding coordinator / Author / Translator) beside a search box (`#apd-search-name`), then a **user table** (`#apd-users-table` with headers Name | Assignments | Affiliation | Reviewing Interest) whose rows are rendered **client-side** into `#apd-users-tbody` from `window.__apUsers` (all `OjsLanding.User.all()` via `reviewer_json/1`, passed from the controller as the `ap_users_json` JSON string; Assignments = `reviews_completed`, Reviewing Interest = `reviewing_interests`). `apdFilterUsers()` re-renders the table filtering by role + name/email (`u.role` compared to the dropdown value, empty-state `#apd-no-results` "No users found."); clicking a row adds `.apd-user-selected` and stores the selection in the hidden form. Below the table a **Message section** (`apd-message-section`) shows "Choose a predefined message to use, or fill out the form below.", a predefined-message dropdown (`#apd-predefined-message`: Discussion (Submission) / Assign Editor → fills the editor via `apdApplyPredefinedMessage`), and a rich-text editor (`.apd-richtext-toolbar` B/I/U/bullet + contenteditable `#apd-message-editor`, synced into hidden `message`). Footer has **Cancel** and **OK** (`apd-btn-ok`); OK POSTs the hidden `#assign-participant-form` to `/dashboard/editorial/assign-editor` (alert "Please select a user first." if none selected); the drawer closes via back-arrow / Cancel / backdrop / Escape
  - **`workflow_3_1` layout**: redesigned as a two-column grid (`.wf-two-col-layout`, same as `workflow_1`). Page heading `.wf-page-heading` shows "WORKFLOW: REVIEW (ROUND 1)". Left column (`.wf-col-main`) stacks: **Status Info** card (`.wf-status-box` with "Round 1 Status"; shows "Waiting for reviewers to be assigned." when no assignments, else "{n} reviewer assignment(s) in this round."), **Revisions Uploaded** card (Upload button `.wf-btn-link` in header `#btn-upload-revision`; table ALWAYS renders with columns `NO | FILE NAME | DATE UPLOADED | TYPE`, rows only from files with `has_revisions == true` via `Enum.filter(@submission.files || [], &(&1[:has_revisions] == true))`, or a single colspan row `.wf-table-empty` when none exist), **Reviewers** card (header button `#btn-add-reviewers` toggles an inline assign form `#assign-reviewer-inline` with classes `.wf-inline-assign`/`.wf-hidden`, POSTs to `/assign-reviewer`; the table ALWAYS renders with columns `REVIEWERS | REVIEWER STATUS | TYPE | ACTIONS` — REVIEWERS = `latest_reviewer/1` (falls back to "Awaiting response"), REVIEWER STATUS = `reviewer_status_label/1`, TYPE = `reviewer_type/1` ("Round N"), ACTIONS = "Open" link to `/review/:id` with `.editorial-view-link`, or a single colspan row `.wf-table-empty` ("No reviewers have been assigned yet.") when no assignments exist), **Review Discussions** card (header button `#btn-add-discussion-review`; table ALWAYS renders with columns `Name | From | Last Reply | Replies | Closed`, populated from all assignments' `discussions` via `review_discussions/1` + `discussion_last_reply/1` + `discussion_replies_count/1` + `discussion_closed_label/1`, or a single colspan row `.wf-table-empty` when none exist). Right column (`.wf-col-side`) for editors holds an **Action Panel** card with full-width `.wf-btn-action` buttons: Request Revisions (POST `/request-revisions`), Accept Submission (POST `/accept`), **Create New Review Round** (`#btn-create-new-review-round`, placeholder), **Cancel Review Round** (`#btn-cancel-review-round`, placeholder), Decline Submission (POST `/decline` + confirm). The panel renders only when `@mode != :author` and `@row.status not in [:declined, :published, :scheduled]`; for author mode the right column shows a read-only "Review Progress" card. NOTE: HEEx does not render a non-output `<% if %>` nested inside the `<% else %>` of an outer `<%= if %>` (content silently dropped) — always use `<%= if %>` for the inner block. New CSS: `.wf-page-heading`, `.wf-page-stage-label`, `.wf-status-box`(`-title`/`-text`), `.wf-inline-assign`, `.wf-hidden`, `.wf-action-form`, `.wf-table-empty`
  - Publication menu keys: `publication_titleAbstract`, `publication_metadata`, `publication_citations` (References), `publication_jats` (generated JATS XML preview via `EditorHTML.jats_xml/1`), `publication_galleys`, `publication_issue`, `publication_license`
  - Unknown keys fall back to `workflow_1`; unknown/missing submission ids flash an error and redirect back to the list
  - Title & Abstract / Metadata / References tabs save through POST `/dashboard/editorial/:id/publication` (`EditorController.save_publication/2`) into `OjsLanding.Submission.update/2`, then redirect back preserving `currentViewId` + `workflowMenuKey`
  - The table's **View** button links to this URL using the stage-appropriate menu key (`EditorHTML.default_workflow_menu_for_stage/1`: initial stages → `workflow_1`, review stages → `workflow_3_1`, copyediting → `workflow_4`, production+ → `workflow_5`)
  - `currentViewId` is preserved from the dashboard filter so "Back to Submissions" returns to the correct view
  - Assignment links ("Open", "Manage copyediting", "Open production record") use `.editorial-view-link` class for plain-text styling in review/copyedit/production task tables
- Workflow page CSS is in `assets/css/app.css` (bottom section, "Editorial Workflow Page Styles"), using the OJS 3.5 PKP design system colors: background `#eaedee`, primary `#006798`, stage colors (submission `#d00a0a`, review `#e08914`, copyediting `#006798`, production `#00b28d`), font-family Noto Sans, `border-radius: 2px`, cards with `#ddd` borders. The `workflow_1` view uses a two-column grid layout (`.wf-two-col-layout`: `1fr 300px`) with left column for content cards and right column for action/participant panels
- Editor workflow actions (stage transitions):
  - **Send For Review now opens a 2-step Email Notification wizard** (`send_to_review/2` is no longer triggered directly by the `workflow_1` Action Panel button — that button is now an `<a>` linking to the wizard's Step 1):
    - `GET /dashboard/editorial/:id/send-to-review` (`send_to_review_email/2`, template `editor_html/send_to_review_email.html.heex`) — **Step 1 "Send for Review: Notify authors"**: breadcrumb `Dashboard / (author), (title) / Send for review`, page title `# Send for Review: Notify authors`, subtitle "This submission is ready to be sent for peer review." (no submission summary block — the Submission/Title/Author/stage row was removed), stepper `1. Notify Authors / 2. Select Files` (connector line `.enr-step-connector` stretches to fill the row, `flex: 1 1 auto`), left **Email Templates** card (search input "Find Template" + template list; selecting a template fills Subject + message body via JS), right compose column with `To` (read-only primary contact name via `EditorController.primary_contact/1`), `Subject` (default "Your submission has been sent for review"), a rich-text editor (`.enr-richtext[data-target]` contenteditable + `.enr-toolbar` bold/italic/underline/bullet, synced by `initRichtextEditors()` in `assets/js/app.js`), and bottom-right **Cancel** (→ `workflow_1`) + **Continue** (→ Step 2). CSS classes use the `enr-` prefix in `assets/css/app.css`
    - `GET /dashboard/editorial/:id/send-to-review/select-files` (`send_to_review_files/2`, template `editor_html/send_to_review_files.html.heex`) — **Step 2 "Select files"**: submission files table with checkboxes, **Go Back** (→ Step 1), and a **Send for Review** form that POSTs to `send_to_review/2` to perform the actual transition
  - `POST /dashboard/editorial/:id/send-to-review` (`send_to_review/2`) — performs the transition; sets status `:active`, stage `:external_review`. This endpoint is reached from Step 2 of the email wizard
  - `POST /dashboard/editorial/:id/request-revisions` (`request_revisions/2`) — sets status `:revisions_requested`, stage `:external_review`
  - `POST /dashboard/editorial/:id/accept` (`accept_submission/2`) — sets status `:scheduled`, stage `:production`
  - `POST /dashboard/editorial/:id/decline` (`decline_submission/2`) — sets status `:declined`
  - `POST /dashboard/editorial/assign-editor` (`assign_editor/2`) — appends editor info (from `OjsLanding.User`) to the submission's `editors` list via `Submission.assign_editor/2`. When a hidden `workflowMenuKey` is present (assign from the workflow Assign Participant drawer), it redirects **back to the same workflow page** via `assign_editor_redirect/3` → `EditorHTML.workflow_menu_path/3` (preserving `currentViewId`), instead of the dashboard list
  - Action buttons appear in the workflow view per stage: Send For Review (→ email wizard) + Accept and Skip Review + Decline Submission in `workflow_1`; Request Revisions + Accept Submission + (placeholder Create New Review Round / Cancel Review Round) + Decline Submission in the `workflow_3_1` right-side Action Panel; Accept & Schedule + Decline in `workflow_5`
- Editorial activity log: `/dashboard/editorial/activity/:id?currentViewId=<view>` (`EditorController.activity/2`, template `editor_html/activity.html.heex`) — opened by the **Activity** button in the table's EDITORIAL ACTIVITY column. Shows a timeline derived from store data (created/files/submitted/review history/copyedit & proofread tasks/galleys/published) via `EditorHTML.activity_events/2`, newest first, plus an "Open Workflow" link back to the stage-appropriate workflow menu
- Reviewer assignment accept/decline: `/review/:id` (`ReviewerController.review/2`) — when assignment status is `:action_required`, the review page shows an "Accept Review" and "Decline Review" button pair instead of the review form. Accepting sets status to `:in_progress`, declining sets it to `:declined` and redirects back to the assignments list
  - `POST /review/:id/accept` (`ReviewerController.accept_review/2`) — transitions `:action_required` → `:in_progress`
  - `POST /review/:id/decline` (`ReviewerController.decline_review/2`) — transitions `:action_required`/`:in_progress` → `:declined`
- Reviewer review wizard: after accepting, the reviewer walks through 4 wizard steps (Request / Guidelines / Download & Review / Completion) driven by `assignment.wizard_step` (`ReviewerAssignment.advance_review_step/1` + `go_back_review_step/1`, POST `/review/:id/step` and `/review/:id/go-back`). Step 2 shows Review Guidelines + a consent checkbox and "Continue to Step #3" (`btn-continue-guidelines`). Step 2's "Go Back" returns to Step 1 (Request), which reuses the Request for Review page with a "Continue to Step #2" primary action (instead of Accept) once the review is accepted (`status: :in_progress, wizard_step: 1`); `advance_review_step` accepts steps 1–3 and `go_back_review_step` accepts steps 2–4 so the wizard can always walk forward/backward
- **Step 3 = Reviewer Review Page** (`review.html.heex`, rendered when `status: :in_progress and wizard_step == 3`, CSS classes with `rp-` prefix in `assets/css/app.css`, section "Reviewer Review Page (OJS 3.5 PKP style)"): a full OJS 3.5-style review interface built of stacked `.rp-panel` cards
  - **Review Files** panel: header with title (left) + Search button (right), files table (File/Date/Type) from `@assignment.files`
  - **Review** panel: instruction text "Enter (or paste) your review of this submission into the form below.", then the review form (`id="review-form"`, POST `/review/:id` → `ReviewerController.submit_review/2`) with two rich-text editors — "For Author and Editor" (`comments_author`) and "For Editor" (`comments_editor`). The editors use `.rp-richtext[data-target]` contenteditable divs with `.rp-toolbar` (bold/italic/underline/bullet) synced into hidden inputs by `initRichtextEditors()` in `assets/js/app.js`
  - **Upload** panel (helper text only)
  - **Reviewer Files** panel: header with Search + Upload File buttons, empty state body
  - **Review Discussions** panel: header with "Add Discussion" button, empty state body
  - **Recommendation** panel: `<select>` (`name="recommendation"`, `form="review-form"`) with options Choose one (placeholder) / Accept Submission / Revisions Required / Resubmit for Review / Resubmit Elsewhere / Decline Submission / See Comments
  - **Actions** panel footer: "Go back" (form POST `/review/:id/go-back`), "Save For Later" (non-functional placeholder button `rp-btn-save-later`), "Submit Review" (submits `#review-form` → `submit_review/2` which sets status `:completed`, stage `:copyediting`, records `recommendation`/`comments_author`/`comments_editor` into the assignment and appends to `review_history`)
  - The form uses a single `<form id="review-form">` for the rich-text editors (each editor has a `form`-less hidden input inside the form); the recommendation `<select>` sits outside that form and is tied to it via the `form="review-form"` attribute
- After submitting, assignment 1 lands on the `:completed` view showing "Review Submitted" + the recommendation/comments and the copyediting stage panels

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
custom classes must fully style the input

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
- **Never** use `@apply` when writing raw css
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline <script>custom js</script> tags within templates**

### UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions


<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages
<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->

<!-- phoenix:html-start -->
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
<!-- phoenix:html-end -->

<!-- phoenix:liveview-start -->
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
         socket
         |> assign(:messages_empty?, messages == [])
         # reset the stream with the new messages
         |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items
  along with the updated assign:

      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)
        edit_form = to_form(Chat.change_message(message, %{content: message.content}))

        # re-insert message so @editing_message_id toggle logic takes effect for that stream item
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:editing_message_id, String.to_integer(message_id))
         |> assign(:edit_form, edit_form)}
      end

  And in the template:

      <div id="messages" phx-update="stream">
        <div :for={{id, message} <- @streams.messages} id={id} class="flex group">
          {message.username}
          <%= if @editing_message_id == message.id do %>
            <%!-- Edit mode --%>
            <.form for={@edit_form} id="edit-form-#{message.id}" phx-submit="save_edit">
              ...
            </.form>
          <% end %>
        </div>
      </div>

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView JavaScript interop

- Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Always** provide an unique DOM id alongside `phx-hook` otherwise a compiler error will be raised

LiveView hooks come in two flavors, 1) colocated js hooks for "inline" scripts defined inside HEEx,
and 2) external `phx-hook` annotations where JavaScript object literals are defined and passed to the `LiveSocket` constructor.

#### Inline colocated js hooks

**Never** write raw embedded `<script>` tags in heex as they are incompatible with LiveView.
Instead, **always use a colocated js hook script tag (`:type={Phoenix.LiveView.ColocatedHook}`)
when writing scripts inside the template**:

    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }
    </script>

- colocated hooks are automatically integrated into the app.js bundle
- colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.PhoneNumber`

#### External phx-hook

External JS hooks (`<div id="myhook" phx-hook="MyHook">`) must be placed in `assets/js/` and passed to the
LiveSocket constructor:

    const MyHook = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { MyHook }
    });

#### Pushing events between client and server

Use LiveView's `push_event/3` when you need to push events/data to the client for a phx-hook to handle.
**Always** return or rebind the socket on `push_event/3` when pushing events:

    # re-bind socket so we maintain event state to be pushed
    socket = push_event(socket, "my_event", %{...})

    # or return the modified socket directly:
    def handle_event("some_event", _, socket) do
      {:noreply, push_event(socket, "my_event", %{...})}
    end

Pushed events can then be picked up in a JS hook with `this.handleEvent`:

    mounted() {
      this.handleEvent("my_event", data => console.log("from server:", data));
    }

Clients can also push an event to the server and receive a reply with `this.pushEvent`:

    mounted() {
      this.el.addEventListener("click", e => {
        this.pushEvent("my_event", { one: 1 }, reply => console.log("got reply from server:", reply));
      })
    }

Where the server handled it via:

    def handle_event("my_event", %{"one" => 1}, socket) do
      {:reply, %{two: 2}, socket}
    end

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset
<!-- phoenix:liveview-end -->

<!-- usage-rules-end -->