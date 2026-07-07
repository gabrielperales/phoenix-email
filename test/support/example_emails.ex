defmodule PhoenixEmail.ExampleEmails do
  @moduledoc false
  # Ports of react-email's demo templates (https://demo.react.email),
  # used to golden-test the rendered output of full, realistic emails.
  use PhoenixEmail

  def vercel_invite(assigns) do
    ~H"""
    <.email>
      <.head />
      <.preview>Join {@invited_by_username} on Vercel</.preview>
      <.body style="background-color:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif">
        <.container style="border:1px solid #eaeaea;border-radius:4px;margin:40px auto;padding:20px;max-width:465px">
          <.section style="margin-top:32px">
            <.img src="https://react.email/static/vercel-logo.png" width="40" height="37" alt="Vercel" style="margin:0 auto" />
          </.section>
          <.heading as="h1" style="color:#000000;font-size:24px;font-weight:normal;text-align:center;padding:0;margin:30px 0">
            Join <strong>{@team_name}</strong> on <strong>Vercel</strong>
          </.heading>
          <.text style="color:#000000;font-size:14px;line-height:24px">Hello {@username},</.text>
          <.text style="color:#000000;font-size:14px;line-height:24px">
            <strong>{@invited_by_username}</strong> (<.link href={"mailto:#{@invited_by_email}"} style="color:#2563eb;text-decoration:none">{@invited_by_email}</.link>) has invited you to the <strong>{@team_name}</strong> team on <strong>Vercel</strong>.
          </.text>
          <.section>
            <.row>
              <.column align="right">
                <.img src={@user_image} width="64" height="64" alt={@username} style="border-radius:9999px" />
              </.column>
              <.column align="center">
                <.img src="https://react.email/static/vercel-arrow.png" width="12" height="9" alt="invited you to" />
              </.column>
              <.column align="left">
                <.img src={@team_image} width="64" height="64" alt={@team_name} style="border-radius:9999px" />
              </.column>
            </.row>
          </.section>
          <.section style="text-align:center;margin-top:32px;margin-bottom:32px">
            <.button href={@invite_link} style="background-color:#000000;color:#ffffff;border-radius:4px;font-size:12px;font-weight:600;text-align:center;padding:12px 20px">
              Join the team
            </.button>
          </.section>
          <.text style="color:#000000;font-size:14px;line-height:24px">
            or copy and paste this URL into your browser: <.link href={@invite_link} style="color:#2563eb;text-decoration:none">{@invite_link}</.link>
          </.text>
          <.hr style="border:1px solid #eaeaea;margin:26px 0;width:100%" />
          <.text style="color:#666666;font-size:12px;line-height:24px">
            This invitation was intended for <span style="color:#000000">{@username}</span>. This invite was sent from <span style="color:#000000">{@invite_from_ip}</span>
            located in <span style="color:#000000">{@invite_from_location}</span>. If you were not expecting this invitation, you can ignore this email.
          </.text>
        </.container>
      </.body>
    </.email>
    """
  end

  def stripe_welcome(assigns) do
    ~H"""
    <.email>
      <.head />
      <.preview>You're now ready to make live transactions with Stripe!</.preview>
      <.body style="background-color:#f6f9fc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif">
        <.container style="background-color:#ffffff;margin:0 auto;padding:20px 0 48px;margin-bottom:64px">
          <.section style="padding:0 48px">
            <.img src="https://react.email/static/stripe-logo.png" width="49" height="21" alt="Stripe" />
            <.hr style="border-color:#e6ebf1;margin:20px 0" />
            <.text style="color:#525f7f;font-size:16px;line-height:24px;text-align:left">
              Thanks for submitting your account information. You're now ready to make live transactions with Stripe!
            </.text>
            <.text style="color:#525f7f;font-size:16px;line-height:24px;text-align:left">
              You can view your payments and a variety of other information about your account right from your dashboard.
            </.text>
            <.button href="https://dashboard.stripe.com/login" style="background-color:#656ee8;border-radius:5px;color:#ffffff;font-size:16px;font-weight:bold;text-align:center;display:block;width:100%;padding:10px 10px">
              View your Stripe Dashboard
            </.button>
            <.hr style="border-color:#e6ebf1;margin:20px 0" />
            <.text style="color:#525f7f;font-size:16px;line-height:24px;text-align:left">
              If you haven't finished your integration, you might find our <.link href="https://stripe.com/docs" style="color:#556cd6">docs</.link> handy.
            </.text>
            <.text style="color:#525f7f;font-size:16px;line-height:24px;text-align:left">
              Once you're ready to start accepting payments, you'll just need to use your live <.link href="https://dashboard.stripe.com/login?redirect=%2Fapikeys" style="color:#556cd6">API keys</.link>
              instead of your test API keys. Your account can simultaneously be used for both test and live requests, so you can continue testing while accepting live payments.
            </.text>
            <.text style="color:#525f7f;font-size:16px;line-height:24px;text-align:left">— The Stripe team</.text>
            <.hr style="border-color:#e6ebf1;margin:20px 0" />
            <.text style="color:#8898aa;font-size:12px;line-height:16px">Stripe, 354 Oyster Point Blvd, South San Francisco, CA 94080</.text>
          </.section>
        </.container>
      </.body>
    </.email>
    """
  end

  def notion_magic_link(assigns) do
    ~H"""
    <.email>
      <.head>
        <.font font_family="Inter" fallback_font_family="Helvetica" web_font={%{url: "https://fonts.gstatic.com/s/inter/v12/inter.woff2", format: "woff2"}} />
      </.head>
      <.preview>Log in with this magic link</.preview>
      <.body style="background-color:#ffffff">
        <.container style="padding-left:12px;padding-right:12px;margin:0 auto">
          <.heading as="h1" style="color:#333333;font-size:24px;font-weight:bold;margin:40px 0;padding:0">Login</.heading>
          <.link href={@login_url} style="color:#2754C5;font-size:14px;text-decoration:underline;display:block;margin-bottom:16px">Click here to log in with this magic link</.link>
          <.text style="color:#333333;font-size:14px;margin:24px 0">Or, copy and paste this temporary login code:</.text>
          <code style="display:inline-block;padding:16px 4.5%;width:90.5%;background-color:#f4f4f4;border-radius:5px;border:1px solid #eeeeee;color:#333333">{@login_code}</code>
          <.text style="color:#ababab;font-size:14px;margin:16px 0 14px">If you didn't try to login, you can safely ignore this email.</.text>
          <.img src="https://react.email/static/notion-logo.png" width="32" height="32" alt="Notion" />
          <.text style="color:#898989;font-size:12px;line-height:22px;margin-top:12px">
            <.link href="https://notion.so" style="color:#898989;font-size:14px;text-decoration:underline">Notion.so</.link>, the all-in-one workspace for your notes, tasks, wikis, and databases.
          </.text>
        </.container>
      </.body>
    </.email>
    """
  end
end
