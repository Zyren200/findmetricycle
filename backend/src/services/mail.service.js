const nodemailer = require("nodemailer");
const env = require("../config/env");
const escapeHtml = require("../utils/escape-html");

function buildTransporter() {
  return nodemailer.createTransport({
    host: env.mail.smtpHost,
    port: env.mail.smtpPort,
    secure: false,
    auth: {
      user: env.mail.senderEmail,
      pass: env.mail.smtpPassword,
    },
  });
}

// [fromName] is the sender name the recipient sees; the address is always
// the Brevo sender.
async function sendMail({ to, subject, html, replyTo, fromName = "FindMeTricycle" }) {
  try {
    const transporter = buildTransporter();
    await transporter.sendMail({
      from: { name: fromName, address: env.mail.fromEmail },
      to,
      subject,
      html,
      ...(replyTo ? { replyTo } : {}),
    });
    console.log(`✓ Email sent to ${to}: ${subject}`);
    return true;
  } catch (error) {
    console.error(`✗ Failed to send email to ${to} (${subject}):`, error.message);
    return false;
  }
}

async function sendDriverApprovalEmail(email, fullName) {
  return sendMail({
    to: email,
    subject: "🎉 Driver Application Approved!",
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #0E8C46;">Congratulations, ${escapeHtml(fullName)}!</h2>
        <p>Your driver application has been <strong>approved</strong>.</p>
        <p>You can now switch to Driver Mode in the FindMeTricycle app and start accepting rides.</p>
        <hr style="border: none; border-top: 1px solid #ccc; margin: 20px 0;">
        <p style="color: #666; font-size: 12px;">&copy; FindMeTricycle</p>
      </div>
    `,
  });
}

async function sendDriverRejectionEmail(email, fullName, reason) {
  return sendMail({
    to: email,
    subject: "Driver Application Status Update",
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #D32F2F;">Application Update</h2>
        <p>Hi ${escapeHtml(fullName)},</p>
        <p>Thank you for applying as a driver. Unfortunately, your application was not approved at this time.</p>
        <p><strong>Reason:</strong></p>
        <div style="background: #fff3cd; padding: 15px; border-radius: 6px; border-left: 4px solid #FFC107;">
          ${escapeHtml(reason || "Please contact support for more details.")}
        </div>
        <hr style="border: none; border-top: 1px solid #ccc; margin: 20px 0;">
        <p style="color: #666; font-size: 12px;">&copy; FindMeTricycle</p>
      </div>
    `,
  });
}

async function sendDriverCorrectionEmail(email, fullName, note) {
  return sendMail({
    to: email,
    subject: "Driver Application Needs Correction",
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #F2BE35;">Action Required</h2>
        <p>Hi ${escapeHtml(fullName)},</p>
        <p>Your driver application needs an update before it can be reviewed further.</p>
        <div style="background: #fff3cd; padding: 15px; border-radius: 6px; border-left: 4px solid #FFC107;">
          ${escapeHtml(note || "Please review your submitted documents and resubmit.")}
        </div>
        <hr style="border: none; border-top: 1px solid #ccc; margin: 20px 0;">
        <p style="color: #666; font-size: 12px;">&copy; FindMeTricycle</p>
      </div>
    `,
  });
}

// Sent when a Super Admin adds an admin ("welcome") or asks them to reset
// their password ("reset"). Never contains a password or a code: the admin
// sets their own password with Forgot password on the sign-in page, and the
// code arrives in a separate email they request themselves.
async function sendAdminAccessEmail(email, fullName, { kind = "welcome", roleLabel = "Admin" } = {}) {
  const signIn = env.adminDashboardUrl
    ? `<a href="${escapeHtml(env.adminDashboardUrl)}">${escapeHtml(env.adminDashboardUrl)}</a>`
    : "the FindMeTricycle admin dashboard";
  const welcome = kind === "welcome";
  return sendMail({
    to: email,
    subject: welcome ? "Your FindMeTricycle admin account" : "Reset your FindMeTricycle admin password",
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #0E8C46;">FindMeTricycle</h2>
        <p>Hi ${escapeHtml(fullName)},</p>
        ${
          welcome
            ? `<p>An admin account was created for you with the role <strong>${escapeHtml(roleLabel)}</strong>.</p>
               <p>To set your password:</p>`
            : `<p>A Super Admin asked you to reset your admin password.</p>
               <p>To set a new password:</p>`
        }
        <ol>
          <li>Open ${signIn}.</li>
          <li>Click <strong>Forgot password?</strong></li>
          <li>Enter this email address (${escapeHtml(email)}) and follow the code we send you.</li>
        </ol>
        <p>Nobody else knows or sets your password. If you weren't expecting this email, you can ignore it.</p>
        <hr style="border: none; border-top: 1px solid #ccc; margin: 20px 0;">
        <p style="color: #666; font-size: 12px;">&copy; FindMeTricycle</p>
      </div>
    `,
  });
}

// Keeps the line breaks an admin typed.
function paragraphs(text) {
  return escapeHtml(text).replace(/\r?\n/g, "<br>");
}

// An admin's answer to a Contact page message, quoting what the person
// wrote. It's a no-reply email: nobody reads replies to it, so it says to
// send a new message from the Contact page instead.
async function sendContactReplyEmail({ to, name, subject, originalMessage, reply }) {
  const topic = subject || "your message";
  return sendMail({
    to,
    fromName: env.mail.supportFromName,
    subject: `Re: ${subject || "Your message to FindMeTricycle"}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #0E8C46;">FindMeTricycle Support</h2>
        <p>Hi ${escapeHtml(name)},</p>
        <p>Thank you for contacting us about ${escapeHtml(topic)}. Here is our reply:</p>
        <div style="background: #f4f8f5; padding: 15px; border-radius: 6px; border-left: 4px solid #0E8C46;">
          ${paragraphs(reply)}
        </div>
        <p style="margin-top: 24px; color: #666; font-size: 13px;">Your message:</p>
        <div style="color: #666; font-size: 13px; padding-left: 12px; border-left: 3px solid #ccc;">
          ${paragraphs(originalMessage)}
        </div>
        <p style="margin-top: 24px; color: #666; font-size: 12px;">
          This is an automated email. Please don't reply to it — replies aren't read.
          If you need more help, send us a new message from the Contact page on the FindMeTricycle website.
        </p>
        <hr style="border: none; border-top: 1px solid #ccc; margin: 20px 0;">
        <p style="color: #666; font-size: 12px;">&copy; FindMeTricycle</p>
      </div>
    `,
  });
}

module.exports = {
  sendMail,
  sendContactReplyEmail,
  sendDriverApprovalEmail,
  sendDriverRejectionEmail,
  sendDriverCorrectionEmail,
  sendAdminAccessEmail,
};
