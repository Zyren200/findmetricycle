require("./setup-env");

const mockSendMail = jest.fn(async () => ({}));
jest.mock("nodemailer", () => ({ createTransport: () => ({ sendMail: mockSendMail }) }));

const env = require("../src/config/env");
const mailService = require("../src/services/mail.service");

beforeEach(() => mockSendMail.mockClear());

describe("email sender", () => {
  it("Contact Support replies come from the support name, on the OTP sender address", async () => {
    await mailService.sendContactReplyEmail({
      to: "juan@gmail.com",
      name: "Juan",
      subject: "Fare question",
      originalMessage: "How much?",
      reply: "About ₱40.",
    });

    expect(mockSendMail).toHaveBeenCalledWith(
      expect.objectContaining({
        from: { name: "support.findmetricycle", address: env.mail.fromEmail },
        to: "juan@gmail.com",
        subject: "Re: Fare question",
      })
    );
    // A no-reply email: no Reply-To, and it says not to reply.
    const email = mockSendMail.mock.calls[0][0];
    expect(email.replyTo).toBeUndefined();
    expect(email.html).toContain("Please don't reply to it");
  });

  it("other emails keep the FindMeTricycle name", async () => {
    await mailService.sendDriverApprovalEmail("ramon@gmail.com", "Ramon");
    expect(mockSendMail.mock.calls[0][0].from).toEqual({ name: "FindMeTricycle", address: env.mail.fromEmail });
  });
});
