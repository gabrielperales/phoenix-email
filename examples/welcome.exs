# Renders the README's welcome email to welcome.html and welcome.txt.
#
#     mix run examples/welcome.exs

defmodule Examples.Welcome do
  use PhoenixEmail

  def welcome(assigns) do
    ~H"""
    <.email>
      <.head />
      <.preview>You're in — let's get you set up</.preview>
      <.body style="background-color:#f6f9fc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif">
        <.container style="background-color:#ffffff;margin:40px auto;padding:20px 48px;border-radius:8px">
          <.heading as="h1" style="font-size:24px;color:#1a1a1a">Hello {@name}</.heading>
          <.text style="color:#525f7f">Thanks for signing up. Click the button below to get started.</.text>
          <.section style="padding:16px 0">
            <.button href={@url} style="background-color:#5e6ad2;color:#ffffff;padding:12px 20px;border-radius:8px;font-size:14px;font-weight:600">
              Get started
            </.button>
          </.section>
          <.row>
            <.column style="width:50%">
              <.text style="color:#8898aa;font-size:12px">Column one</.text>
            </.column>
            <.column>
              <.text style="color:#8898aa;font-size:12px">Column two</.text>
            </.column>
          </.row>
          <.hr style="margin:24px 0" />
          <.link href="https://example.com" style="font-size:12px;color:#8898aa">example.com</.link>
        </.container>
      </.body>
    </.email>
    """
  end
end

assigns = %{name: "Ada", url: "https://example.com/start"}

html = PhoenixEmail.render(&Examples.Welcome.welcome/1, assigns)
text = PhoenixEmail.render(&Examples.Welcome.welcome/1, assigns, plain_text: true)

File.write!("welcome.html", html)
File.write!("welcome.txt", text)

IO.puts(
  "Wrote welcome.html (#{byte_size(html)} bytes) and welcome.txt (#{byte_size(text)} bytes)"
)
