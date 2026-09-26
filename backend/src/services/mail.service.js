const nodemailer = require("nodemailer");
const env = require("../config/env");

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

async function sendMail({ to, subject, html }) {
  try {
    const transporter = buildTransporter();
    await transporter.sendMail({
      from: `"FindMeTricycle" <${env.mail.fromEmail}>`,
      to,
      subject,
      html,
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
        <h2 style="color: #0E8C46;">Congratulations, ${fullName}!</h2>
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
        <p>Hi ${fullName},</p>
        <p>Thank you for applying as a driver. Unfortunately, your application was not approved at this time.</p>
        <p><strong>Reason:</strong></p>
        <div style="background: #fff3cd; padding: 15px; border-radius: 6px; border-left: 4px solid #FFC107;">
          ${reason || "Please contact support for more details."}
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
        <p>Hi ${fullName},</p>
        <p>Your driver application needs an update before it can be reviewed further.</p>
        <div style="background: #fff3cd; padding: 15px; border-radius: 6px; border-left: 4px solid #FFC107;">
          ${note || "Please review your submitted documents and resubmit."}
        </div>
        <hr style="border: none; border-top: 1px solid #ccc; margin: 20px 0;">
        <p style="color: #666; font-size: 12px;">&copy; FindMeTricycle</p>
      </div>
    `,
  });
}

module.exports = {
  sendMail,
  sendDriverApprovalEmail,
  sendDriverRejectionEmail,
  sendDriverCorrectionEmail,
};
