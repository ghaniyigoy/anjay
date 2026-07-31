defmodule OjsLanding.Submission do
  @moduledoc """
  Submission module
  """

  defstruct [:id, :author_username, :title, :abstract, :status, :files, :contributors, :created_at]

  @doc """
  Get all submissions
  """
  def all do
    [
      %__MODULE__{
        id: 1,
        author_username: "author1",
        title: "Implementasi Machine Learning untuk Analisis Sentimen",
        abstract: "Penelitian ini membahas implementasi machine learning...",
        status: :active,
        files: [],
        contributors: ["Ahmad Fauzi"],
        created_at: DateTime.utc_now()
      }
    ]
  end

  @doc """
  Get submissions by author username
  """
  def get_by_author(username) do
    all() |> Enum.filter(fn s -> s.author_username == username end)
  end

  @doc """
  Get submission by ID
  """
  def get_by_id(id) do
    Enum.find(all(), fn s -> s.id == id end)
  end
end
