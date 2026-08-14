defmodule OjsLandingWeb.Router do
  use OjsLandingWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OjsLandingWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug OjsLandingWeb.Plugs.Auth
  end

  # ============================================
  # ROUTE UTAMA
  # ============================================
  scope "/", OjsLandingWeb do
    pipe_through :browser

    get "/", JournalController, :index

    # Backward compatibility
    get "/journals/:id", JournalController, :redirect_old_journal

    # Global Auth Routes
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    get "/logout", SessionController, :delete

    get "/register", RegistrationController, :new
    post "/register", RegistrationController, :create

    # Dashboard & Profile Routes
    get "/dashboard", DashboardController, :index
    get "/profile", ProfileController, :index

    # Reviewer Review Routes
    get "/review/:id", ReviewerController, :review
    post "/review/:id", ReviewerController, :submit_review
    post "/review/:id/advance", ReviewerController, :advance_stage
    post "/review/:id/copyedit/:task", ReviewerController, :complete_copyedit
    post "/review/:id/galley", ReviewerController, :add_galley
    post "/review/:id/proofread/:task", ReviewerController, :complete_proofread
    post "/review/:id/publish", ReviewerController, :publish

    # Editor Dashboard Routes
    get "/dashboard/editorial", EditorController, :editorial

    # Editor DOI Article Registration Routes
    get "/dashboard/doiArticles", DoiArticleController, :index

    # Reviewer Dashboard Routes
    get "/dashboard/reviewAssignments", ReviewerController, :review_assignments

    # Author Submission Routes (OJS-style)
    get "/dashboard/mySubmissions", AuthorController, :my_submissions
    get "/submission/new", AuthorController, :new_submission
    post "/submission/create", AuthorController, :create_submission
    get "/submission/wizard", AuthorController, :new_submission
    post "/submission/wizard", AuthorController, :create_submission
    get "/submission/wizard/:id", AuthorController, :edit_submission
    put "/submission/wizard/:id", AuthorController, :update_submission
    get "/submission/wizard/:id/saved", AuthorController, :saved_submission

    # Make a Submission: Details (OJS 3.5 wizard)
    get "/submission/:id/details", AuthorController, :details
    post "/submission/:id/details", AuthorController, :save_details
  end

  # ============================================
  # ROUTE ADMIN
  # ============================================
  scope "/admin", OjsLandingWeb do
    pipe_through :browser

    get "/", AdminController, :index
    get "/index", AdminController, :index
    get "/contexts", AdminController, :contexts
    get "/settings", AdminController, :settings
    get "/wizard/:id", AdminController, :wizard
    get "/systemInfo", AdminController, :system_info
    get "/phpinfo", AdminController, :php_info
    get "/expireSessions", AdminController, :expire_sessions
    get "/clearTemplateCache", AdminController, :clear_template_cache
    get "/clearDataCache", AdminController, :clear_data_cache
    get "/jobs", AdminController, :jobs
    get "/failedJobs", AdminController, :failed_jobs
    get "/failedJobDetails/:id", AdminController, :failed_job_details
    get "/createJournal", AdminController, :create_journal
    post "/createJournal", AdminController, :create_journal_submit
  end

  # ============================================
  # ROUTE JOURNAL
  # ============================================
  scope "/:journal_path", OjsLandingWeb do
    pipe_through :browser

    # Halaman detail jurnal (Current Issue)
    get "/", JournalController, :show
    get "/issue/current", JournalController, :current_issue

    # Journal management settings (OJS-style: Journal / Website / Workflow / Distribution / Users & Roles)
    get "/management/settings", SettingsController, :index
    get "/management/settings/:section", SettingsController, :show

    # Submission workflow (OJS-style, tab-driven: #details #files #contributors #editors #review)
    get "/submission", JournalController, :submission_workflow

    # Archives
    get "/issue/archive", JournalController, :archives

    # About pages
    get "/about", JournalController, :about
    get "/about/submissions", JournalController, :submissions
    get "/about/editorialMasthead", JournalController, :editorial_masthead
    get "/about/privacy", JournalController, :privacy
    get "/about/contact", JournalController, :contact

    # Issues jurnal
    get "/issues", JournalController, :issues
    get "/dois", SettingsController, :dois
    get "/issue/:issue_id", JournalController, :issue_view
    get "/manageIssues", SettingsController, :manage_issues

    # Statistics (OJS PKP 3.5 style)
    get "/stats/publications/publications", StatsController, :publications
    get "/stats/issues/issues", StatsController, :issues
    get "/stats/context/context", StatsController, :context
    get "/stats/editorial/editorial", StatsController, :editorial
    get "/stats/users/users", StatsController, :users
    get "/stats/counterR5/counterR5", StatsController, :counter_r5
    get "/stats/reports", StatsController, :reports

    # Article routes
    get "/article/:article_id", JournalController, :article_view

    # Journal-specific Auth Routes
    get "/register", RegistrationController, :new
    post "/register", RegistrationController, :create
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    get "/logout", SessionController, :delete
  end

  if Application.compile_env(:ojs_landing, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: OjsLandingWeb.Telemetry
    end
  end
end
