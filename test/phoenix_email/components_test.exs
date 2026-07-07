defmodule PhoenixEmail.ComponentsTest do
  use ExUnit.Case, async: true

  use PhoenixEmail

  defp render(rendered) do
    PhoenixEmail.render(rendered)
  end

  describe "email/1" do
    test "renders the html tag with defaults" do
      assigns = %{}
      html = render(~H|<.email>hi</.email>|)

      assert html =~ ~s(<html dir="ltr" lang="en">hi</html>)
    end

    test "accepts lang and dir" do
      assigns = %{}
      html = render(~H|<.email lang="es" dir="rtl">hi</.email>|)

      assert html =~ ~s(<html dir="rtl" lang="es">)
    end
  end

  describe "head/1" do
    test "renders content-type and apple meta tags" do
      assigns = %{}
      html = render(~H|<.head />|)

      assert html =~ ~s(<meta content="text/html; charset=UTF-8" http-equiv="Content-Type")
      assert html =~ ~s(<meta name="x-apple-disable-message-reformatting")
    end

    test "renders extra content from the slot" do
      assigns = %{}
      html = render(~H|<.head><meta name="color-scheme" content="light" /></.head>|)

      assert html =~ ~s(<meta name="color-scheme" content="light")
    end
  end

  describe "body/1" do
    test "renders the body tag with the given style" do
      assigns = %{}
      html = render(~H|<.body style="background:#fff">hi</.body>|)

      assert html =~ ~s(<body style="background:#fff">hi</body>)
    end
  end

  describe "preview/1" do
    test "renders hidden text padded to 150 characters" do
      assigns = %{}
      html = render(~H|<.preview>Short preview</.preview>|)

      assert html =~ "display:none;overflow:hidden;line-height:1px;opacity:0;max-height:0"
      assert html =~ "Short preview"

      padding_units = length(String.split(html, "\u00A0\u200C")) - 1
      assert padding_units == 150 - String.length("Short preview")
    end

    test "does not pad text longer than 150 characters and truncates it" do
      long = String.duplicate("a", 200)
      assigns = %{long: long}
      html = render(~H|<.preview>{@long}</.preview>|)

      refute html =~ "\u00A0\u200C"
      assert html =~ String.duplicate("a", 150)
      refute html =~ String.duplicate("a", 151)
    end
  end

  describe "container/1" do
    test "renders a centered presentation table capped at 37.5em" do
      assigns = %{}
      html = render(~H|<.container>hi</.container>|)

      assert html =~ ~s(align="center")
      assert html =~ ~s(role="presentation")
      assert html =~ ~s(style="max-width:37.5em")
      assert html =~ "<td>hi</td>"
    end

    test "merges the user style after the default" do
      assigns = %{}
      html = render(~H|<.container style="background:#fff">hi</.container>|)

      assert html =~ ~s(style="max-width:37.5em;background:#fff")
    end
  end

  describe "section/1" do
    test "renders a full-width presentation table" do
      assigns = %{}
      html = render(~H|<.section style="padding:24px">hi</.section>|)

      assert html =~ ~s(width="100%")
      assert html =~ ~s(role="presentation")
      assert html =~ ~s(style="padding:24px")
      assert html =~ "<td>hi</td>"
    end
  end

  describe "row/1 and column/1" do
    test "renders columns as cells of a table row" do
      assigns = %{}

      html =
        render(~H"""
        <.row>
          <.column style="width:50%">left</.column>
          <.column>right</.column>
        </.row>
        """)

      assert html =~ ~s(<tbody style="width:100%">)
      assert html =~ ~s(<tr style="width:100%">)
      assert html =~ ~s(<td style="width:50%">left</td>)
      assert html =~ "<td>right</td>"
    end
  end

  describe "heading/1" do
    test "renders an h1 by default" do
      assigns = %{}
      html = render(~H|<.heading>Title</.heading>|)

      assert html =~ "<h1>Title</h1>"
    end

    test "renders the tag given in as" do
      assigns = %{}
      html = render(~H|<.heading as="h3">Title</.heading>|)

      assert html =~ "<h3"
      assert html =~ "</h3>"
    end

    test "converts margin attributes to css, user style last" do
      assigns = %{}
      html = render(~H|<.heading mt={8} mx="auto" style="color:#333">Title</.heading>|)

      assert html =~
               ~s(style="margin-left:auto;margin-right:auto;margin-top:8px;color:#333")
    end
  end

  describe "text/1" do
    test "renders a paragraph with email-safe defaults" do
      assigns = %{}
      html = render(~H|<.text>Body</.text>|)

      assert html =~ ~s(<p style="font-size:14px;line-height:24px;margin:16px 0">Body</p>)
    end

    test "user style can override the defaults" do
      assigns = %{}
      html = render(~H|<.text style="font-size:12px">Body</.text>|)

      assert html =~ ~s(style="font-size:14px;line-height:24px;margin:16px 0;font-size:12px")
    end
  end

  describe "link/1" do
    test "renders an anchor opening in a new tab with default color" do
      assigns = %{}
      html = render(~H|<.link href="https://example.com">visit</.link>|)

      assert html =~ ~s(href="https://example.com")
      assert html =~ ~s(target="_blank")
      assert html =~ ~s(style="color:#067df7;text-decoration-line:none")
      assert html =~ ">visit</a>"
    end
  end

  describe "button/1" do
    test "parses padding from the style and renders the MSO hack" do
      assigns = %{}

      html =
        render(
          ~H|<.button href="https://example.com" style="background:#000;padding:12px 20px">Go</.button>|
        )

      assert html =~ ~s(href="https://example.com")
      assert html =~ "padding:12px 20px 12px 20px"
      assert html =~ "line-height:100%;text-decoration:none;display:inline-block"

      assert html =~
               ~s(<!--[if mso]><i style="mso-font-width:100%;mso-text-raise:18" hidden>&#8202;</i><![endif]-->)

      assert html =~ "mso-text-raise:9"

      assert html =~
               ~s(<!--[if mso]><i style="mso-font-width:100%" hidden>&#8202;&#8203;</i><![endif]-->)

      assert html =~ ">Go</span>"
    end

    test "supports padding longhands and defaults to zero" do
      assigns = %{}

      html =
        render(~H|<.button href="https://example.com" style="padding-left:10px">Go</.button>|)

      assert html =~ "padding:0px 0px 0px 10px"
      assert html =~ "mso-font-width:50%"
    end

    test "renders without a style" do
      assigns = %{}
      html = render(~H|<.button href="https://example.com">Go</.button>|)

      assert html =~ "padding:0px 0px 0px 0px"
    end
  end

  describe "img/1" do
    test "renders an image with email client resets" do
      assigns = %{}

      html =
        render(~H|<.img src="https://example.com/a.png" alt="Logo" width="120" height="40" />|)

      assert html =~ ~s(src="https://example.com/a.png")
      assert html =~ ~s(alt="Logo")
      assert html =~ ~s(width="120")
      assert html =~ ~s(height="40")
      assert html =~ ~s(style="display:block;outline:none;border:none;text-decoration:none")
    end
  end

  describe "hr/1" do
    test "renders a divider with defaults merged with user style" do
      assigns = %{}
      html = render(~H|<.hr style="margin:20px 0" />|)

      assert html =~
               ~s(style="width:100%;border:none;border-top:1px solid #eaeaea;margin:20px 0")
    end
  end

  describe "font/1" do
    test "renders a font-face declaration with outlook fallback" do
      assigns = %{}

      html =
        render(
          ~H|<.font font_family="Roboto" web_font={%{url: "https://f.example/r.woff2", format: "woff2"}} />|
        )

      assert html =~ "@font-face"
      assert html =~ "font-family: 'Roboto';"
      assert html =~ "mso-font-alt: 'Verdana';"
      assert html =~ "src: url(https://f.example/r.woff2) format('woff2');"
      assert html =~ "font-family: 'Roboto', Verdana;"
    end
  end
end
