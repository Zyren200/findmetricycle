const API_URL = "https://api.brevo.com/v3/smtp/email";

async function sendBrevoEmail({
  to,
  subject,
  html,
  fromName = "FindMeTricycle",
  replyTo,
}) {
  const apiKey = process.env.BREVO_API_KEY;
  const senderEmail = (
    process.env.BREVO_FROM_EMAIL ||
    process.env.BREVO_SENDER_EMAIL ||
    ""
  ).trim();

  if (!apiKey) {
    throw new Error("BREVO_API_KEY is not configured");
  }

  if (
    !senderEmail ||
    senderEmail.endsWith(".local")
  ) {
    throw new Error(
      "Set BREVO_FROM_EMAIL to a verified Brevo sender email"
    );
  }

  const payload = {
    sender: {
      name: fromName,
      email: senderEmail,
    },
    to: [{ email: to }],
    subject,
    htmlContent: html,
    ...(replyTo
      ? {
          replyTo:
            typeof replyTo === "string"
              ? { email: replyTo }
              : replyTo,
        }
      : {}),
  };

  const response = await fetch(API_URL, {
    method: "POST",
    headers: {
      accept: "application/json",
      "api-key": apiKey,
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(15000),
  });

  if (!response.ok) {
    const details = (await response.text()).slice(0, 500);
    throw new Error(
      `Brevo API returned ${response.status}: ${details}`
    );
  }

  return response.json().catch(() => ({}));
}

module.exports = { sendBrevoEmail };
