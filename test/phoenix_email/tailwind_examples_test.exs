defmodule PhoenixEmail.TailwindExamplesTest do
  use ExUnit.Case, async: false

  alias PhoenixEmail.Tailwind
  alias PhoenixEmail.TailwindEmails

  # Golden regression over react-email's canonical Tailwind demo
  # (vercel-invite-user.tsx) ported class-for-class. The compiled tailwind
  # map is a committed fixture so this runs without the tailwindcss binary;
  # regenerate map and goldens after changing classes or the compiler:
  #
  #     mix run -e '...Compiler.run(content: ["test/support/tailwind_emails.ex"], ...)'
  #     REGEN_FIXTURES=1 mix test test/phoenix_email/tailwind_examples_test.exs
  #
  @fixtures_dir Path.expand("../fixtures", __DIR__)

  @assigns %{
    username: "alanturing",
    user_image: "https://react.email/static/vercel-user.png",
    invited_by_username: "Alan",
    invited_by_email: "alan.turing@example.com",
    team_name: "Enigma",
    team_image: "https://react.email/static/vercel-team.png",
    invite_link: "https://vercel.com",
    invite_from_ip: "204.13.186.218",
    invite_from_location: "São Paulo, Brazil"
  }

  setup do
    {map, _} = Code.eval_file(Path.join(@fixtures_dir, "tailwind_map.exs"))
    Tailwind.put_map(map)
    on_exit(fn -> Tailwind.put_map(%{}) end)
  end

  test "matches the golden HTML and plain text output" do
    html = PhoenixEmail.render(&TailwindEmails.vercel_invite/1, @assigns)
    text = PhoenixEmail.render(&TailwindEmails.vercel_invite/1, @assigns, plain_text: true)

    if System.get_env("REGEN_FIXTURES") do
      File.write!(fixture_path("vercel_invite_tailwind.html"), html)
      File.write!(fixture_path("vercel_invite_tailwind.txt"), text)
    end

    assert html == File.read!(fixture_path("vercel_invite_tailwind.html"))
    assert text == File.read!(fixture_path("vercel_invite_tailwind.txt"))
  end

  test "classes translate to inline styles only — no class attributes survive" do
    html = PhoenixEmail.render(&TailwindEmails.vercel_invite/1, @assigns)

    refute html =~ "class="
  end

  test "the button keeps the Outlook padding hack from px-5 py-3" do
    html = PhoenixEmail.render(&TailwindEmails.vercel_invite/1, @assigns)

    assert html =~ "padding:12px 20px 12px 20px"
    assert html =~ ~s(mso-font-width:100%;mso-text-raise:18)
  end

  test "v4 conversions land in the rendered document" do
    html = PhoenixEmail.render(&TailwindEmails.vercel_invite/1, @assigns)

    # rounded-full via calc(infinity * 1px), blue-600 via oklch
    assert html =~ "border-radius:9999px"
    assert html =~ "color:#155dfc"
    # tw/1 helper on raw span tags
    assert html =~ ~s(<span style="color:#000000">alanturing</span>)
  end

  defp fixture_path(name), do: Path.join(@fixtures_dir, name)
end
