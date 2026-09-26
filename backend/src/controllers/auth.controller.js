const authService = require("../services/auth.service");

async function registerPassenger(req, res, next) {
  try {
    const result = await authService.registerPassenger({
      fullName: req.body.fullName,
      phone: req.body.phone,
      email: req.body.email,
      password: req.body.password,
    });

    res.status(201).json({
      success: true,
      message: "Passenger registration successful.",
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

async function registerAdmin(req, res, next) {
  try {
    const result = await authService.registerAdmin({
      fullName: req.body.fullName,
      phone: req.body.phone,
      email: req.body.email,
      password: req.body.password,
    });

    res.status(201).json({
      success: true,
      message: "Admin account created.",
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

async function adminExists(req, res, next) {
  try {
    const exists = await authService.adminExists();
    res.json({ success: true, data: { exists } });
  } catch (error) {
    next(error);
  }
}

async function sendAdminOtp(req, res, next) {
  try {
    const result = await authService.sendAdminOtp(req.body.email);
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
}

async function verifyAdminOtp(req, res, next) {
  try {
    const result = await authService.verifyAdminOtp(req.body.email, req.body.code);
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
}

async function requestAdminPasswordReset(req, res, next) {
  try {
    const result = await authService.requestAdminPasswordReset();
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
}

async function verifyAdminPasswordResetOtp(req, res, next) {
  try {
    const result = await authService.verifyAdminPasswordResetOtp(req.body.code);
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
}

async function resetAdminPassword(req, res, next) {
  try {
    const result = await authService.resetAdminPassword(req.body.newPassword);
    res.json({ success: true, ...result });
  } catch (error) {
    next(error);
  }
}

async function login(req, res, next) {
  try {
    const result = await authService.login({
      email: req.body.email,
      phone: req.body.phone,
      password: req.body.password,
    });

    res.json({
      success: true,
      message: "Login successful.",
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

async function refresh(req, res, next) {
  try {
    const result = await authService.refreshAccessToken({
      refreshToken: req.body.refreshToken,
    });

    res.json({
      success: true,
      message: "Token refreshed.",
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

async function logout(req, res, next) {
  try {
    await authService.logout({
      refreshToken: req.body.refreshToken,
    });

    res.json({
      success: true,
      message: "Logged out.",
    });
  } catch (error) {
    next(error);
  }
}

async function logoutAll(req, res, next) {
  try {
    await authService.logoutAll({
      userId: req.user.id,
    });

    res.json({
      success: true,
      message: "Logged out from all sessions.",
    });
  } catch (error) {
    next(error);
  }
}

function me(req, res) {
  res.json({
    success: true,
    data: req.user,
  });
}

module.exports = {
  registerPassenger,
  registerAdmin,
  adminExists,
  sendAdminOtp,
  verifyAdminOtp,
  requestAdminPasswordReset,
  verifyAdminPasswordResetOtp,
  resetAdminPassword,
  login,
  refresh,
  logout,
  logoutAll,
  me,
};
