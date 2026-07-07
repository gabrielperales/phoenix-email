defmodule PhoenixEmail.ExamplesTest do
  use ExUnit.Case, async: true

  alias PhoenixEmail.ExampleEmails

  # Golden tests over full templates ported from react-email's demos.
  # Regenerate the fixtures after an intentional output change with:
  #
  #     REGEN_FIXTURES=1 mix test test/phoenix_email/examples_test.exs
  #
  # and review the fixture diff before committing.
  @fixtures_dir Path.expand("../fixtures", __DIR__)

  @invite_assigns %{
    username: "alanturing",
    invited_by_username: "Alan",
    invited_by_email: "alan.turing@example.com",
    team_name: "Enigma",
    user_image: "https://demo.react.email/static/vercel-user.png",
    team_image: "https://demo.react.email/static/vercel-team.png",
    invite_link: "https://vercel.com/teams/invite/foo",
    invite_from_ip: "204.13.186.218",
    invite_from_location: "São Paulo, Brazil"
  }

  @magic_link_assigns %{
    login_url: "https://notion.so/login?code=sparo-ndigo-amurt-secan",
    login_code: "sparo-ndigo-amurt-secan"
  }

  describe "vercel invite" do
    test "matches the golden HTML and plain text output" do
      assert_golden(&ExampleEmails.vercel_invite/1, @invite_assigns, "vercel_invite")
    end

    test "interpolates the assigns" do
      html = PhoenixEmail.render(&ExampleEmails.vercel_invite/1, @invite_assigns)

      assert html =~ "Join <strong>Enigma</strong> on <strong>Vercel</strong>"
      assert html =~ ~s(href="mailto:alan.turing@example.com")
      assert html =~ "São Paulo, Brazil"
    end

    test "button reproduces react-email's Outlook padding hack" do
      html = PhoenixEmail.render(&ExampleEmails.vercel_invite/1, @invite_assigns)

      # padding:12px 20px -> pl*5 = 100%, (pt+pb)*0.75 = 18
      assert html =~ "padding:12px 20px 12px 20px"
      assert html =~ ~s(mso-font-width:100%;mso-text-raise:18)
    end

    test "avatar row renders the three aligned columns" do
      html = PhoenixEmail.render(&ExampleEmails.vercel_invite/1, @invite_assigns)

      assert html =~ ~s(<td align="right">)
      assert html =~ ~s(<td align="center">)
      assert html =~ ~s(<td align="left">)
    end
  end

  describe "stripe welcome" do
    test "matches the golden HTML and plain text output" do
      assert_golden(&ExampleEmails.stripe_welcome/1, %{}, "stripe_welcome")
    end

    test "button reproduces react-email's Outlook padding hack" do
      html = PhoenixEmail.render(&ExampleEmails.stripe_welcome/1)

      # padding:10px 10px -> pr*5 = 50%, (pt+pb)*0.75 = 15
      assert html =~ "padding:10px 10px 10px 10px"
      assert html =~ ~s(mso-font-width:50%;mso-text-raise:15)
    end

    test "plain text keeps the dashboard call to action" do
      text = PhoenixEmail.render(&ExampleEmails.stripe_welcome/1, %{}, plain_text: true)

      assert text =~ "View your Stripe Dashboard [https://dashboard.stripe.com/login]"
      assert text =~ "docs [https://stripe.com/docs]"
      refute text =~ "<"
    end
  end

  describe "notion magic link" do
    test "matches the golden HTML and plain text output" do
      assert_golden(&ExampleEmails.notion_magic_link/1, @magic_link_assigns, "notion_magic_link")
    end

    test "declares the web font with its Outlook fallback" do
      html = PhoenixEmail.render(&ExampleEmails.notion_magic_link/1, @magic_link_assigns)

      assert html =~ "font-family: 'Inter';"
      assert html =~ "mso-font-alt: 'Helvetica';"

      assert html =~
               "src: url(https://fonts.gstatic.com/s/inter/v12/inter.woff2) format('woff2');"
    end

    test "plain text keeps the login code and skips the preview" do
      text =
        PhoenixEmail.render(&ExampleEmails.notion_magic_link/1, @magic_link_assigns,
          plain_text: true
        )

      assert text =~ "sparo-ndigo-amurt-secan"
      refute text =~ "Log in with this magic link"
    end
  end

  defp assert_golden(fun, assigns, name) do
    html = PhoenixEmail.render(fun, assigns)
    text = PhoenixEmail.render(fun, assigns, plain_text: true)

    if System.get_env("REGEN_FIXTURES") do
      File.mkdir_p!(@fixtures_dir)
      File.write!(fixture_path(name, "html"), html)
      File.write!(fixture_path(name, "txt"), text)
    end

    assert html == File.read!(fixture_path(name, "html"))
    assert text == File.read!(fixture_path(name, "txt"))
  end

  defp fixture_path(name, extension) do
    Path.join(@fixtures_dir, "#{name}.#{extension}")
  end
end
