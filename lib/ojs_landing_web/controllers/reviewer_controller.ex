defmodule OjsLandingWeb.ReviewerController do
  use OjsLandingWeb, :controller

  def review_assignments(conn, %{"currentViewId" => view_id} = _params) do
    user = conn.assigns.current_user

    # Filter review assignments berdasarkan view_id
    all_assignments = OjsLanding.ReviewerAssignment.all()

    filtered_assignments =
      case view_id do
        "reviewer-action-required" ->
          Enum.filter(all_assignments, fn a -> a.status == :action_required end)

        "reviewer-assignments-all" ->
          all_assignments

        "reviewer-assignments-completed" ->
          Enum.filter(all_assignments, fn a -> a.status == :completed end)

        "reviewer-assignments-declined" ->
          Enum.filter(all_assignments, fn a -> a.status == :declined end)

        "reviewer-assignments-published" ->
          Enum.filter(all_assignments, fn a -> a.status == :published end)

        "reviewer-assignments-archived" ->
          Enum.filter(all_assignments, fn a -> a.status == :archived end)

        _ ->
          all_assignments
      end

    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
    |> render(:review_assignments,
      assignments: filtered_assignments,
      all_assignments: all_assignments,
      current_view: view_id || "reviewer-action-required",
      user: user
    )
  end

  def review_assignments(conn, _params) do
    review_assignments(conn, %{"currentViewId" => "reviewer-action-required"})
  end

  def review(conn, %{"id" => id}) do
    if is_nil(conn.assigns.current_user) do
      conn
      |> put_flash(:error, "Silakan login terlebih dahulu untuk mengakses halaman review.")
      |> redirect(to: "/login")
    else
      do_review(conn, id)
    end
  end

  defp do_review(conn, id) do
    assignment = get_review_assignment(id)

    case assignment do
      nil ->
        conn
        |> put_flash(:error, "Review assignment not found")
        |> redirect(to: "/dashboard/reviewAssignments")

      assignment ->
        user = conn.assigns.current_user

        conn
        |> put_root_layout(false)
        |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
        |> render(:review,
          assignment: assignment,
          user: user,
          criteria: review_criteria()
        )
    end
  end

  def submit_review(conn, %{"id" => id} = params) do
    reviewer =
      case conn.assigns.current_user do
        %OjsLanding.User{given_name: given, family_name: family} ->
          String.trim("#{given} #{family}")

        name when is_binary(name) ->
          name

        _ ->
          "You"
      end

    params = Map.put_new(params, "reviewer", reviewer)

    case OjsLanding.ReviewerAssignment.submit_review(id, params) do
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Review assignment not found")
        |> redirect(to: "/dashboard/reviewAssignments")

      {:ok, assignment} ->
        recommendation = assignment.recommendation || "None"

        conn
        |> put_flash(
          :info,
          "Review submitted for \"#{assignment.title}\" (recommendation: #{recommendation})."
        )
        |> redirect(to: "/review/#{id}")
    end
  end

  def advance_stage(conn, %{"id" => id}) do
    conn = login_guard(conn)

    if conn.state == :sent do
      conn
    else
      case OjsLanding.ReviewerAssignment.get(id) do
        nil ->
          conn
          |> put_flash(:error, "Review assignment not found")
          |> redirect(to: "/dashboard/reviewAssignments")

        %{stage: :copyediting} = assignment ->
          if Enum.all?(assignment.copyedit_tasks, & &1.done) do
            {:ok, _assignment} = OjsLanding.ReviewerAssignment.set_stage(id, :production)

            conn
            |> put_flash(:info, "Submission has been moved to the Production stage.")
            |> redirect(to: "/review/#{id}")
          else
            conn
            |> put_flash(
              :error,
              "Complete all copyediting tasks before advancing to Production."
            )
            |> redirect(to: "/review/#{id}")
          end

        _assignment ->
          conn
          |> put_flash(:error, "This submission is not ready to advance to Production.")
          |> redirect(to: "/review/#{id}")
      end
    end
  end

  def complete_copyedit(conn, %{"id" => id, "task" => task}) do
    conn = login_guard(conn)

    if conn.state == :sent do
      conn
    else
      case OjsLanding.ReviewerAssignment.complete_copyedit_task(id, task) do
        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Review assignment not found")
          |> redirect(to: "/dashboard/reviewAssignments")

        {:ok, _assignment} ->
          conn
          |> put_flash(:info, "Copyediting task marked as complete.")
          |> redirect(to: "/review/#{id}")
      end
    end
  end

  def add_galley(conn, %{"id" => id} = params) do
    conn = login_guard(conn)

    if conn.state == :sent do
      conn
    else
      case OjsLanding.ReviewerAssignment.add_galley_file(id, params) do
        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Review assignment not found")
          |> redirect(to: "/dashboard/reviewAssignments")

        {:ok, _assignment} ->
          conn
          |> put_flash(:info, "Galley file added.")
          |> redirect(to: "/review/#{id}")
      end
    end
  end

  def complete_proofread(conn, %{"id" => id, "task" => task}) do
    conn = login_guard(conn)

    if conn.state == :sent do
      conn
    else
      case OjsLanding.ReviewerAssignment.complete_proofread_task(id, task) do
        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Review assignment not found")
          |> redirect(to: "/dashboard/reviewAssignments")

        {:ok, _assignment} ->
          conn
          |> put_flash(:info, "Proofreading task marked as complete.")
          |> redirect(to: "/review/#{id}")
      end
    end
  end

  def publish(conn, %{"id" => id} = params) do
    conn = login_guard(conn)

    if conn.state == :sent do
      conn
    else
      case OjsLanding.ReviewerAssignment.get(id) do
        nil ->
          conn
          |> put_flash(:error, "Review assignment not found")
          |> redirect(to: "/dashboard/reviewAssignments")

        %{status: :published} ->
          conn
          |> put_flash(:error, "This submission has already been published.")
          |> redirect(to: "/review/#{id}")

        %{stage: :production, proofread_tasks: tasks} ->
          if Enum.all?(tasks, & &1.done) do
            {:ok, _assignment} = OjsLanding.ReviewerAssignment.publish(id, params)

            conn
            |> put_flash(:info, "Submission published successfully.")
            |> redirect(to: "/review/#{id}")
          else
            conn
            |> put_flash(:error, "Complete all proofreading tasks before publishing.")
            |> redirect(to: "/review/#{id}")
          end

        _assignment ->
          conn
          |> put_flash(:error, "This submission is not in the Production stage.")
          |> redirect(to: "/review/#{id}")
      end
    end
  end

  defp login_guard(conn) do
    if is_nil(conn.assigns.current_user) do
      conn
      |> put_flash(:error, "Silakan login terlebih dahulu untuk mengakses halaman review.")
      |> redirect(to: "/login")
    else
      conn
    end
  end

  defp get_review_assignment(id) do
    OjsLanding.ReviewerAssignment.get(id)
  end

  defp review_criteria do
    [
      %{
        label: "Originality",
        question: "Is the manuscript original and does it contribute new knowledge to the field?"
      },
      %{
        label: "Relevance",
        question: "Is the manuscript relevant to the scope and focus of the journal?"
      },
      %{
        label: "Methodology",
        question: "Are the research methods sound, rigorous, and clearly described?"
      },
      %{
        label: "Data & Analysis",
        question: "Are the data, results, and analysis presented clearly and correctly?"
      },
      %{
        label: "Clarity & Structure",
        question: "Is the manuscript well-written, well-organized, and easy to follow?"
      }
    ]
  end
end
