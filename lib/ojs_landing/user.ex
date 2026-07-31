defmodule OjsLanding.User do
  @moduledoc """
  User management module
  """

  defstruct [:id, :username, :password, :email, :given_name, :family_name, :affiliation, :country, :role]

  @doc """
  Get all users
  """
  def all do
    [
      %__MODULE__{
        id: 1,
        username: "alief",
        password: "password123",
        email: "alief@admin.com",
        given_name: "Alief",
        family_name: "Admin",
        affiliation: "OJS Admin",
        country: "Indonesia",
        role: :admin
      },
      %__MODULE__{
        id: 2,
        username: "author1",
        password: "password123",
        email: "author1@informatika.ac.id",
        given_name: "Ahmad",
        family_name: "Fauzi",
        affiliation: "Universitas Teknologi",
        country: "Indonesia",
        role: :author
      },
      %__MODULE__{
        id: 3,
        username: "author",
        password: "password123",
        email: "author@test.com",
        given_name: "Test",
        family_name: "Author",
        affiliation: "Test University",
        country: "Indonesia",
        role: :author
      },
      %__MODULE__{
        id: 4,
        username: "reviewer",
        password: "password123",
        email: "reviewer@test.com",
        given_name: "Dr. Siti",
        family_name: "Nurhaliza",
        affiliation: "Research Institute",
        country: "Indonesia",
        role: :reviewer
      },
      %__MODULE__{
        id: 5,
        username: "editor",
        password: "password123",
        email: "editor@test.com",
        given_name: "Prof. Budi",
        family_name: "Santoso",
        affiliation: "University Press",
        country: "Indonesia",
        role: :editor
      }
    ]
  end

  @doc """
  Find user by username
  """
  def find_by_username(username) do
    Enum.find(all(), fn user -> user.username == username end)
  end

  @doc """
  Find user by email
  """
  def find_by_email(email) do
    Enum.find(all(), fn user -> user.email == email end)
  end

  @doc """
  Verify login credentials
  """
  def verify_login(username_or_email, password) do
    user = find_by_username(username_or_email) || find_by_email(username_or_email)

    cond do
      is_nil(user) ->
        {:error, "Username atau email tidak ditemukan"}
      user.password != password ->
        {:error, "Password salah"}
      true ->
        {:ok, user}
    end
  end

  @doc """
  Register new user
  """
  def register(params) do
    username = params["username"]

    if find_by_username(username) do
      {:error, "Username sudah digunakan"}
    else
      new_user = %__MODULE__{
        id: System.unique_integer([:positive]),
        username: username,
        password: params["password"],
        email: params["email"],
        given_name: params["given_name"],
        family_name: params["family_name"] || "",
        affiliation: params["affiliation"] || "",
        country: params["country"] || "Indonesia",
        role: :author
      }

      {:ok, new_user}
    end
  end
end
