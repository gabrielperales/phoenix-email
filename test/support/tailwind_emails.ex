defmodule PhoenixEmail.TailwindEmails do
  @moduledoc false
  # Port of react-email's canonical Tailwind demo
  # (apps/demo/emails/Community/notifications/vercel-invite-user.tsx) with the
  # exact same utility classes, used for visual/golden regression against the
  # build-time compiled tailwind map in test/fixtures/tailwind_map.exs.
  use PhoenixEmail

  def vercel_invite(assigns) do
    ~H"""
    <.email>
      <.head />
      <.body class="mx-auto my-auto bg-white px-2 font-sans">
        <.preview>Join {@invited_by_username} on Vercel</.preview>
        <.container class="mx-auto my-[40px] max-w-[465px] rounded border border-[#eaeaea] border-solid p-[20px]">
          <.section class="mt-[32px]">
            <.img src="https://react.email/static/vercel-logo.png" width="40" height="37" alt="Vercel Logo" class="mx-auto my-0" />
          </.section>
          <.heading class="mx-0 my-[30px] p-0 text-center font-normal text-[24px] text-black">
            Join <strong>{@team_name}</strong> on <strong>Vercel</strong>
          </.heading>
          <.text class="text-[14px] text-black leading-[24px]">Hello {@username},</.text>
          <.text class="text-[14px] text-black leading-[24px]">
            <strong>{@invited_by_username}</strong> (<.link href={"mailto:#{@invited_by_email}"} class="text-blue-600 no-underline">{@invited_by_email}</.link>) has invited you to the <strong>{@team_name}</strong> team on <strong>Vercel</strong>.
          </.text>
          <.section>
            <.row>
              <.column align="right">
                <.img class="rounded-full" src={@user_image} width="64" height="64" alt="profile picture" />
              </.column>
              <.column align="center">
                <.img src="https://react.email/static/vercel-arrow.png" width="12" height="9" alt="Arrow indicating invitation" />
              </.column>
              <.column align="left">
                <.img class="rounded-full" src={@team_image} width="64" height="64" alt="team logo" />
              </.column>
            </.row>
          </.section>
          <.section class="mt-[32px] mb-[32px] text-center">
            <.button href={@invite_link} class="rounded bg-[#000000] px-5 py-3 text-center font-semibold text-[12px] text-white no-underline">
              Join the team
            </.button>
          </.section>
          <.text class="text-[14px] text-black leading-[24px]">
            or copy and paste this URL into your browser: <.link href={@invite_link} class="text-blue-600 no-underline">{@invite_link}</.link>
          </.text>
          <.hr class="mx-0 my-[26px] w-full border border-[#eaeaea] border-solid" />
          <.text class="text-[#666666] text-[12px] leading-[24px]">
            This invitation was intended for <span style={tw("text-black")}>{@username}</span>. This invite was sent from <span style={tw("text-black")}>{@invite_from_ip}</span>
            located in <span style={tw("text-black")}>{@invite_from_location}</span>. If you were not expecting this invitation, you can ignore this email.
          </.text>
        </.container>
      </.body>
    </.email>
    """
  end
end
