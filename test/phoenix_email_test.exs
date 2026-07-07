defmodule PhoenixEmailTest do
  use ExUnit.Case, async: true

  alias PhoenixEmail.TestEmails

  @assigns %{name: "Ada", url: "https://example.com/start"}

  describe "render/2 and render/3" do
    test "renders a full email with the react-email doctype" do
      html = PhoenixEmail.render(&TestEmails.welcome/1, @assigns)

      assert String.starts_with?(
               html,
               ~s(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN")
             )

      assert html =~ ~s(<html dir="ltr" lang="en">)
      assert html =~ "Hello Ada"
      assert html =~ ~s(href="https://example.com/start")
      assert html =~ "<!--[if mso]>"
      assert html =~ ~s(role="presentation")
    end

    test "accepts an already rendered template" do
      import Phoenix.Component, only: [sigil_H: 2]
      import PhoenixEmail.Components, only: [text: 1]

      assigns = %{}
      html = PhoenixEmail.render(~H|<.text>hi</.text>|)

      assert html =~ "<p style="
      assert html =~ ">hi</p>"
    end

    test "renders the kitchen sink email" do
      html = PhoenixEmail.render(&TestEmails.kitchen_sink/1)

      assert html =~ ~s(<html dir="rtl" lang="es">)
      assert html =~ "@font-face"
      assert html =~ ~s(<td style="width:50%">left</td>)
      assert html =~ ~s(<img src="https://example.com/logo.png")
    end
  end

  describe "render/3 with plain_text: true" do
    test "converts the email to plain text" do
      text = PhoenixEmail.render(&TestEmails.welcome/1, @assigns, plain_text: true)

      refute text =~ "<"
      refute text =~ "style"
      assert text =~ "Hello Ada"
      assert text =~ "Thanks for signing up."
      assert text =~ "Get started [https://example.com/start]"
      assert text =~ "https://example.com"
      assert text =~ "----"
    end

    test "skips the preview text and head content" do
      text = PhoenixEmail.render(&TestEmails.welcome/1, @assigns, plain_text: true)

      refute text =~ "let's get you set up"
      refute text =~ "charset"
    end

    test "links keep their label and url" do
      text = PhoenixEmail.render(&TestEmails.welcome/1, @assigns, plain_text: true)

      assert text =~ "example.com [https://example.com]"
    end
  end
end
