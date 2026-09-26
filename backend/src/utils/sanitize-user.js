function sanitizeUser(user) {
  if (!user) return null;

  return {
    id: user.id,
    full_name: user.full_name,
    phone: user.phone,
    email: user.email,
    address: user.address,
    profile_image_url: user.profile_image_url,
    role: user.role,
    status: user.status,
    is_driver_account: Boolean(user.is_driver_account),
    driver_approval_status: user.driver_approval_status || "none",
    created_at: user.created_at,
    updated_at: user.updated_at,
  };
}

module.exports = sanitizeUser;
