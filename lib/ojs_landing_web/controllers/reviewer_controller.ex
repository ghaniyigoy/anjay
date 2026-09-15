defmodule OjsLandingWeb.ReviewerController do
  use OjsLandingWeb, :controller

  def review_assignments(conn, %{"currentViewId" => view_id} = _params) do
    user = conn.assigns.current_user

    # Filter review assignments berdasarkan view_id
    # Mendukung alias OJS: reviewer-action-required, reviewer-assignments-all / reviewer-all,
    # reviewer-completed, reviewer-declined, reviewer-published, reviewer-archived
    all_assignments = OjsLanding.ReviewerAssignment.all()
    normalized = normalize_view_id(view_id)

    filtered_assignments =
      case normalized do
        :action_required ->
          Enum.filter(all_assignments, fn a -> a.status == :action_required end)

        :all ->
          all_assignments

        :completed ->
          Enum.filter(all_assignments, fn a -> a.status == :completed end)

        :declined ->
          Enum.filter(all_assignments, fn a -> a.status == :declined end)

        :published ->
          Enum.filter(all_assignments, fn a -> a.status == :published end)

        :archived ->
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
      current_view: normalized_view_id_string(normalized),
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

  def accept_review(conn, %{"id" => id}) do
    conn = login_guard(conn)

    if conn.state == :sent do
      conn
    else
      case OjsLanding.ReviewerAssignment.accept_assignment(id) do
        {:ok, _assignment} ->
          conn
          |> put_flash(:info, "Review assignment accepted. You may now proceed with the review.")
          |> redirect(to: "/review/#{id}")

        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Review assignment not found")
          |> redirect(to: "/dashboard/reviewAssignments")

        {:error, :invalid_transition} ->
          conn
          |> put_flash(:error, "This assignment cannot be accepted in its current state.")
          |> redirect(to: "/review/#{id}")
      end
    end
  end

  def decline_review(conn, %{"id" => id}) do
    conn = login_guard(conn)

    if conn.state == :sent do
      conn
    else
      case OjsLanding.ReviewerAssignment.decline_assignment(id) do
        {:ok, _assignment} ->
          conn
          |> put_flash(:info, "Review assignment declined.")
          |> redirect(to: "/dashboard/reviewAssignments")

        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Review assignment not found")
          |> redirect(to: "/dashboard/reviewAssignments")

        {:error, :invalid_transition} ->
          conn
          |> put_flash(:error, "This assignment cannot be declined in its current state.")
          |> redirect(to: "/review/#{id}")
      end
    end
  end

  def review_step(conn, %{"id" => id} = params) do
    conn = login_guard(conn)

    if conn.state == :sent do
      conn
    else
      case OjsLanding.ReviewerAssignment.advance_review_step(id, params) do
        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Review assignment not found")
          |> redirect(to: "/dashboard/reviewAssignments")

        {:error, :invalid_transition} ->
          conn
          |> put_flash(:error, "This review wizard cannot be advanced in its current state.")
          |> redirect(to: "/review/#{id}")

        {:ok, _assignment} ->
          conn
          |> redirect(to: "/review/#{id}")
      end
    end
  end

  def review_go_back(conn, %{"id" => id}) do
    conn = login_guard(conn)

    if conn.state == :sent do
      conn
    else
      case OjsLanding.ReviewerAssignment.go_back_review_step(id) do
        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Review assignment not found")
          |> redirect(to: "/dashboard/reviewAssignments")

        {:error, :invalid_transition} ->
          conn
          |> put_flash(:error, "Cannot go back in the current review state.")
          |> redirect(to: "/review/#{id}")

        {:ok, _assignment} ->
          conn
          |> redirect(to: "/review/#{id}")
      end
    end
  end

  def add_reviewer_file(conn, %{"id" => id} = params) do
    conn = login_guard(conn)

    if conn.state == :sent do
      conn
    else
      upload = params["upload"]

      {name, size} =
        case upload do
          %Plug.Upload{filename: filename} ->
            {filename, humanize_size(upload)}

          _ ->
            {params["name"] || "untitled", params["size"] || "—"}
        end

      params = %{
        "name" => name,
        "type" => params["type"] || file_type_from_name(name),
        "size" => size
      }

      case OjsLanding.ReviewerAssignment.add_reviewer_file(id, params) do
        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Review assignment not found")
          |> redirect(to: "/dashboard/reviewAssignments")

        {:ok, _assignment} ->
          conn
          |> put_flash(:info, "Reviewer file uploaded.")
          |> redirect(to: "/review/#{id}")
      end
    end
  end

  def add_discussion(conn, %{"id" => id} = params) do
    conn = login_guard(conn)

    if conn.state == :sent do
      conn
    else
      reviewer =
        case conn.assigns.current_user do
          %OjsLanding.User{given_name: given, family_name: family} ->
            String.trim("#{given} #{family}")

          name when is_binary(name) ->
            name

          _ ->
            "You"
        end

      params = %{
        "subject" => params["subject"] || "Discussion",
        "message" => params["message"] || "",
        "author" => reviewer
      }

      case OjsLanding.ReviewerAssignment.add_discussion(id, params) do
        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Review assignment not found")
          |> redirect(to: "/dashboard/reviewAssignments")

        {:ok, _assignment} ->
          conn
          |> put_flash(:info, "Discussion added.")
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

  defp humanize_size(%Plug.Upload{path: path}) do
    case File.stat(path) do
      {:ok, %{size: bytes}} -> format_bytes(bytes)
      _ -> "—"
    end
  end

  defp humanize_size(_), do: "—"

  defp format_bytes(bytes) when bytes >= 1_048_576 do
    format_float(bytes / 1_048_576) <> " MB"
  end

  defp format_bytes(bytes) when bytes >= 1024 do
    format_float(bytes / 1024) <> " KB"
  end

  defp format_bytes(bytes), do: "#{bytes} B"

  defp format_float(num) do
    rounded = Float.round(num, 1)
    if rounded == trunc(rounded), do: Integer.to_string(trunc(rounded)), else: "#{rounded}"
  end

  defp file_type_from_name(name) do
    cond do
      String.ends_with?(name, [".pdf"]) -> "PDF"
      String.ends_with?(name, [".csv"]) -> "CSV"
      String.ends_with?(name, [".doc", ".docx"]) -> "Word"
      String.ends_with?(name, [".xls", ".xlsx"]) -> "Excel"
      String.ends_with?(name, [".png", ".jpg", ".jpeg", ".gif"]) -> "Image"
      true -> "Other"
    end
  end

  defp normalize_view_id(view_id) when is_binary(view_id) do
    case view_id do
      "reviewer-action-required" -> :action_required
      "reviewer-assignments-all" -> :all
      "reviewer-all" -> :all
      "reviewer-assignments-completed" -> :completed
      "reviewer-completed" -> :completed
      "reviewer-assignments-declined" -> :declined
      "reviewer-declined" -> :declined
      "reviewer-assignments-published" -> :published
      "reviewer-published" -> :published
      "reviewer-assignments-archived" -> :archived
      "reviewer-archived" -> :archived
      _ -> :all
    end
  end

  defp normalize_view_id(_), do: :action_required

  defp normalized_view_id_string(:action_required), do: "reviewer-action-required"
  defp normalized_view_id_string(:all), do: "reviewer-assignments-all"
  defp normalized_view_id_string(:completed), do: "reviewer-assignments-completed"
  defp normalized_view_id_string(:declined), do: "reviewer-assignments-declined"
  defp normalized_view_id_string(:published), do: "reviewer-assignments-published"
  defp normalized_view_id_string(:archived), do: "reviewer-assignments-archived"
  defp normalized_view_id_string(_), do: "reviewer-action-required"

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
