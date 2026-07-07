defmodule PhoenixEmail.TestEmails do
  @moduledoc false
  use PhoenixEmail

  def welcome(assigns) do
    ~H"""
    <.email>
      <.head />
      <.preview>You're in — let's get you set up</.preview>
      <.body style="background-color:#ffffff">
        <.container>
          <.heading as="h1">Hello {@name}</.heading>
          <.text>Thanks for signing up.</.text>
          <.button
            href={@url}
            style="background-color:#5e6ad2;color:#fff;padding:12px 20px;border-radius:8px"
          >
            Get started
          </.button>
          <.hr />
          <.link href="https://example.com">example.com</.link>
        </.container>
      </.body>
    </.email>
    """
  end

  def kitchen_sink(assigns) do
    ~H"""
    <.email lang="es" dir="rtl">
      <.head>
        <.font
          font_family="Roboto"
          fallback_font_family="Verdana"
          web_font={%{url: "https://fonts.example.com/roboto.woff2", format: "woff2"}}
        />
      </.head>
      <.body>
        <.container style="background:#f6f9fc">
          <.section style="padding:24px">
            <.row>
              <.column style="width:50%">left</.column>
              <.column>right</.column>
            </.row>
          </.section>
          <.heading as="h2" mt={8} mx="auto" style="color:#333">Title</.heading>
          <.text style="color:#525f7f">Body copy</.text>
          <.img src="https://example.com/logo.png" alt="Logo" width="120" height="40" />
          <.hr style="margin:20px 0" />
          <.link href="https://example.com" style="color:#8898aa">visit us</.link>
        </.container>
      </.body>
    </.email>
    """
  end
end
