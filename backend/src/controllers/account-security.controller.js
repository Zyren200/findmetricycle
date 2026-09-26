const accountSecurityService = require("../services/account-security.service");

async function requestPasswordChangeOtp(req, res, next) {
  try {
    const result = await accountSecurityService.requestPasswordChangeOtp(
      req.user.id,
      req.body.currentPassword
    );
    res.json(result);
  } catch (error) {
    next(error);
  }
}

async function confirmPasswordChange(req, res, next) {
  try {
    const result = await accountSecurityService.confirmPasswordChange(req.user.id, {
      currentPassword: req.body.currentPassword,
      newPassword: req.body.newPassword,
      otp: req.body.otp,
    });
    res.json(result);
  } catch (error) {
    next(error);
  }
}

module.exports = {
  requestPasswordChangeOtp,
  confirmPasswordChange,
};
