defmodule PhoenixEmail.ExtrasTest do
  use ExUnit.Case, async: true

  use PhoenixEmail

  defp render(rendered) do
    PhoenixEmail.render(rendered)
  end

  describe "code_inline/1" do
    test "renders a code tag with the given style" do
      assigns = %{}
      html = render(~H|<.code_inline style="background:#f4f4f4">mix test</.code_inline>|)

      assert html =~ ~s(<code style="background:#f4f4f4">mix test</code>)
    end

    test "escapes its content" do
      assigns = %{}
      html = render(~H|<.code_inline>{"<script>"}</.code_inline>|)

      assert html =~ "&lt;script&gt;"
    end
  end

  describe "code_block/1" do
    @code """
    defmodule Hello do
      # greet
      def world, do: "hi"
    end
    """

    test "highlights known languages with inline-styled spans" do
      assigns = %{code: @code}
      html = render(~H|<.code_block code={@code} language="elixir" />|)

      assert html =~ ~s(<span style="color:#d73a49">defmodule</span>)
      assert html =~ ~s(<span style="color:#6f42c1">Hello</span>)
      assert html =~ ~s(<span style="color:#6a737d;font-style:italic"># greet</span>)
      assert html =~ ~s(<span style="color:#032f62">&quot;hi&quot;</span>)
    end

    test "applies the theme base style to the pre tag, user style last" do
      assigns = %{code: @code}
      html = render(~H|<.code_block code={@code} language="elixir" style="margin:16px 0" />|)

      assert html =~ ~s(<pre style="background:#f6f8fa;)
      assert html =~ ";margin:16px 0\">"
    end

    test "falls back to escaped plain code for unknown languages" do
      assigns = %{}
      html = render(~H|<.code_block code="a < b" language="brainfuck" />|)

      refute html =~ "<span"
      assert html =~ "a &lt; b"
    end

    test "accepts a custom theme" do
      assigns = %{code: @code, theme: %{base: "background:#000", keyword: "color:#ff0000"}}
      html = render(~H|<.code_block code={@code} language="elixir" theme={@theme} />|)

      assert html =~ ~s(<pre style="background:#000">)
      assert html =~ ~s(<span style="color:#ff0000">def</span>)
      refute html =~ "#6f42c1"
    end
  end

  describe "markdown/1" do
    @markdown """
    # Changelog

    Hello **world**, check the [docs](https://example.com/docs).

    - one
    - two

    > quoted

    ```elixir
    1 + 1
    ```

    ---
    """

    test "renders markdown with default inline styles" do
      assigns = %{markdown: @markdown}
      html = render(~H|<.markdown content={@markdown} />|)

      assert html =~
               ~s(<h1 style="font-size:32px;font-weight:700;line-height:40px;margin:24px 0 12px">Changelog</h1>)

      assert html =~ "<strong>world</strong>"

      assert html =~
               ~s(<a href="https://example.com/docs" style="color:#067df7;text-decoration:none">docs</a>)

      assert html =~ ~s(<li style="font-size:14px;line-height:24px;margin:4px 0">one</li>)
      assert html =~ ~s(<blockquote style="border-left:4px solid #eaeaea;)

      assert html =~
               ~s(<hr class="thin" style="width:100%;border:none;border-top:1px solid #eaeaea;margin:16px 0"/>)
    end

    test "fenced code keeps the pre style without inline-code styling" do
      assigns = %{markdown: @markdown}
      html = render(~H|<.markdown content={@markdown} />|)

      assert html =~ ~s(<pre style="background:#f6f8fa;)
      assert html =~ ~s(<code class="elixir">1 + 1</code>)
      refute html =~ ~s(<code class="elixir" style=)
    end

    test "custom styles override the defaults per tag" do
      assigns = %{markdown: @markdown, styles: %{h1: "color:#5e6ad2"}}
      html = render(~H|<.markdown content={@markdown} styles={@styles} />|)

      assert html =~ ~s(<h1 style="color:#5e6ad2">Changelog</h1>)
    end

    test "wraps the content in a div with the container style" do
      assigns = %{markdown: "hi"}
      html = render(~H|<.markdown content={@markdown} container_style="padding:0 24px" />|)

      assert html =~ ~s(<div style="padding:0 24px">)
    end

    test "escapes raw HTML in the markdown text" do
      assigns = %{markdown: "safe `<script>` here"}
      html = render(~H|<.markdown content={@markdown} />|)

      assert html =~ "&lt;script&gt;"
      refute html =~ "<script>"
    end
  end

  describe "PhoenixEmail.Swoosh.render_body/3" do
    test "sets html_body and text_body from the same template" do
      email =
        Swoosh.Email.new()
        |> PhoenixEmail.Swoosh.render_body(&PhoenixEmail.TestEmails.welcome/1, %{
          name: "Ada",
          url: "https://example.com/start"
        })

      assert email.html_body =~ "<!DOCTYPE html"
      assert email.html_body =~ "Hello Ada"
      assert email.text_body =~ "Hello Ada"
      assert email.text_body =~ "Get started [https://example.com/start]"
      refute email.text_body =~ "<"
    end
  end
end
