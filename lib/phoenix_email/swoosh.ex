if Code.ensure_loaded?(Swoosh.Email) do
  defmodule PhoenixEmail.Swoosh do
    @moduledoc """
    [Swoosh](https://hex.pm/packages/swoosh) integration.

    Only compiled when the optional `:swoosh` dependency is present.

        import Swoosh.Email

        new()
        |> to({user.name, user.email})
        |> from({"MyApp", "hello@myapp.com"})
        |> subject("Welcome!")
        |> PhoenixEmail.Swoosh.render_body(&MyApp.Emails.welcome/1, %{name: user.name})
    """

    @doc """
    Renders the function component and sets both the `html_body` and the
    `text_body` of the given `Swoosh.Email`.
    """
    def render_body(%Swoosh.Email{} = email, fun, assigns \\ %{}) do
      email
      |> Swoosh.Email.html_body(PhoenixEmail.render(fun, assigns))
      |> Swoosh.Email.text_body(PhoenixEmail.render(fun, assigns, plain_text: true))
    end
  end
end
