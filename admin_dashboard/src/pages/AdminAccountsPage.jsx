import { useCallback, useEffect, useState } from "react";
import { KeyRound, RefreshCw, UserPlus } from "lucide-react";
import { apiClient } from "../api/client";
import PageHero from "../components/PageHero";
import ConfirmDialog from "../components/ConfirmDialog";
import { useToasts } from "../context/ToastContext";
import { formatDateTime } from "../utils/admin-formatters";
import { ROLE_DESCRIPTIONS } from "../utils/admin-access";

const EMPTY_FORM = { fullName: "", email: "", phone: "", role: "operations_admin" };

function errorMessage(err, fallback) {
  const data = err?.response?.data;
  return data?.details?.issues?.[0]?.message || data?.message || fallback;
}

function RoleChip({ role, label }) {
  return <span className={`adm-role-chip role-${role}`}>{label || role}</span>;
}

function StatusCell({ admin }) {
  if (admin.status === "disabled") return <span className="status-pill status-danger">disabled</span>;
  if (!admin.passwordSet) {
    return (
      <span className="status-pill status-warning" title="Hasn't set a password yet">
        setup pending
      </span>
    );
  }
  return <span className="status-pill status-success">active</span>;
}

// Super Admin only: everyone who can sign in to the dashboard, one account
// per person. The backend enforces every rule here; the disabled buttons
// only save a round trip.
export default function AdminAccountsPage() {
  const { addToast } = useToasts();
  const [admins, setAdmins] = useState([]);
  const [roles, setRoles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [busyId, setBusyId] = useState(null);
  const [showCreate, setShowCreate] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);
  const [formError, setFormError] = useState(null);
  const [saving, setSaving] = useState(false);
  // { admin, role } while the change-role dialog is open.
  const [roleEdit, setRoleEdit] = useState(null);
  // { type: "disable" | "enable" | "reset", admin } while a confirm is open.
  const [confirm, setConfirm] = useState(null);

  const load = useCallback(async () => {
    try {
      setError(null);
      const { data } = await apiClient.get("/admin/admins");
      setAdmins(Array.isArray(data?.data) ? data.data : []);
      setRoles(Array.isArray(data?.meta?.roles) ? data.meta.roles : []);
    } catch (err) {
      setError(errorMessage(err, "Failed to load admin accounts."));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const activeSuperAdmins = admins.filter((a) => a.role === "super_admin" && a.status === "active").length;
  const isLastSuperAdmin = (admin) => admin.role === "super_admin" && admin.status === "active" && activeSuperAdmins <= 1;
  const roleLabel = (value) => roles.find((r) => r.value === value)?.label || value;

  async function run(admin, request, success) {
    setBusyId(admin.id);
    try {
      const { data } = await request();
      addToast(data?.message || success, { type: "success" });
      await load();
    } catch (err) {
      addToast(errorMessage(err, "Something went wrong."), { type: "error", duration: 6000 });
    } finally {
      setBusyId(null);
    }
  }

  async function createAdmin(e) {
    e.preventDefault();
    setFormError(null);
    setSaving(true);
    try {
      const { data } = await apiClient.post("/admin/admins", {
        fullName: form.fullName.trim(),
        email: form.email.trim(),
        phone: form.phone.trim(),
        role: form.role,
      });
      addToast(data?.message || "Admin added.", {
        type: data?.meta?.welcomeEmailSent === false ? "warning" : "success",
        duration: 7000,
      });
      setShowCreate(false);
      setForm(EMPTY_FORM);
      await load();
    } catch (err) {
      setFormError(errorMessage(err, "Failed to add the admin."));
    } finally {
      setSaving(false);
    }
  }

  function confirmAction(value) {
    const { type, admin } = confirm;
    setConfirm(null);
    if (!value) return;
    if (type === "disable") {
      run(admin, () => apiClient.post(`/admin/admins/${admin.id}/disable`), "Admin disabled.");
    } else if (type === "enable") {
      run(admin, () => apiClient.post(`/admin/admins/${admin.id}/enable`), "Admin enabled.");
    } else if (type === "reset") {
      run(admin, () => apiClient.post(`/admin/admins/${admin.id}/send-password-reset`), "Email sent.");
    }
  }

  function saveRole() {
    const { admin, role } = roleEdit;
    setRoleEdit(null);
    if (role === admin.role) return;
    run(admin, () => apiClient.put(`/admin/admins/${admin.id}/role`, { role }), "Role updated.");
  }

  const confirmCopy = confirm
    ? {
        disable: {
          title: `Disable ${confirm.admin.fullName}?`,
          message: "They're signed out everywhere right away and can't sign in until an admin enables the account again.",
          label: "Disable",
          danger: true,
        },
        enable: {
          title: `Enable ${confirm.admin.fullName}?`,
          message: "They'll be able to sign in again with their current password.",
          label: "Enable",
          danger: false,
        },
        reset: {
          title: `Send a password reset to ${confirm.admin.fullName}?`,
          message: confirm.admin.passwordSet
            ? `We'll email ${confirm.admin.email} the steps to set a new password with Forgot password. Their current password keeps working until they change it.`
            : `They haven't set a password yet. We'll email ${confirm.admin.email} the setup steps again.`,
          label: "Send email",
          danger: false,
        },
      }[confirm.type]
    : null;

  return (
    <div className="page-stack">
      <PageHero
        title="Admin Accounts"
        description="Everyone who can sign in to this dashboard — one account per person, each with one role."
        actions={
          <>
            <button type="button" className="btn btn-ghost btn-sm" onClick={load}>
              <RefreshCw size={14} /> Refresh
            </button>
            <button
              type="button"
              className="btn btn-primary btn-sm"
              onClick={() => {
                setForm(EMPTY_FORM);
                setFormError(null);
                setShowCreate(true);
              }}
            >
              <UserPlus size={14} /> Add admin
            </button>
          </>
        }
      />

      {error ? <div className="error-banner">{error}</div> : null}

      <section className="panel" style={{ padding: 0 }}>
        <div className="table-wrap">
          <table className="compact-table">
            <thead>
              <tr>
                <th>Admin</th>
                <th>Phone</th>
                <th>Role</th>
                <th>Status</th>
                <th>Last login</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={7}>Loading admin accounts…</td></tr>
              ) : admins.length === 0 ? (
                <tr><td colSpan={7}>No admin accounts.</td></tr>
              ) : (
                admins.map((admin) => {
                  const busy = busyId === admin.id;
                  const lastSuper = isLastSuperAdmin(admin);
                  return (
                    <tr key={admin.id}>
                      <td>
                        <div className="adm-row">
                          <div className="adm-avatar">{(admin.fullName || "?")[0]}</div>
                          <div className="grow">
                            <b style={{ fontSize: 13 }}>
                              {admin.fullName}
                              {admin.isSelf ? <span className="adm-you">you</span> : null}
                            </b>
                            <small>{admin.email}</small>
                          </div>
                        </div>
                      </td>
                      <td>{admin.phone || "-"}</td>
                      <td><RoleChip role={admin.role} label={admin.roleLabel} /></td>
                      <td><StatusCell admin={admin} /></td>
                      <td>{admin.lastLoginAt ? formatDateTime(admin.lastLoginAt) : <span className="muted">Never</span>}</td>
                      <td>
                        {formatDateTime(admin.createdAt)}
                        {admin.createdByName ? <div><small className="muted">by {admin.createdByName}</small></div> : null}
                      </td>
                      <td>
                        {admin.isSelf ? (
                          <small className="muted">Another Super Admin manages your account.</small>
                        ) : (
                          <div className="adm-actions">
                            <button
                              type="button"
                              className="btn btn-ghost btn-sm"
                              disabled={busy || lastSuper || admin.status !== "active"}
                              title={lastSuper ? "The last active Super Admin keeps this role." : undefined}
                              onClick={() => setRoleEdit({ admin, role: admin.role })}
                            >
                              Change role
                            </button>
                            {admin.status === "active" ? (
                              <button
                                type="button"
                                className="btn btn-danger btn-sm"
                                disabled={busy || lastSuper}
                                title={lastSuper ? "The last active Super Admin can't be disabled." : undefined}
                                onClick={() => setConfirm({ type: "disable", admin })}
                              >
                                Disable
                              </button>
                            ) : (
                              <button
                                type="button"
                                className="btn btn-success btn-sm"
                                disabled={busy}
                                onClick={() => setConfirm({ type: "enable", admin })}
                              >
                                Enable
                              </button>
                            )}
                            <button
                              type="button"
                              className="btn btn-ghost btn-sm"
                              disabled={busy || admin.status !== "active"}
                              onClick={() => setConfirm({ type: "reset", admin })}
                            >
                              <KeyRound size={13} /> Send password reset
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </section>

      {showCreate ? (
        <div className="modal-overlay open">
          <form className="modal" style={{ maxWidth: 460 }} onSubmit={createAdmin}>
            <div className="modal-header">
              <div className="modal-title">Add admin</div>
              <button className="modal-close" type="button" onClick={() => setShowCreate(false)}>×</button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label className="form-label" htmlFor="new-admin-name">Full name</label>
                <input
                  id="new-admin-name"
                  className="form-input"
                  value={form.fullName}
                  onChange={(e) => setForm({ ...form, fullName: e.target.value })}
                  required
                  minLength={2}
                  maxLength={120}
                  autoFocus
                />
              </div>
              <div className="form-group">
                <label className="form-label" htmlFor="new-admin-email">Email (their own — used to sign in and reset the password)</label>
                <input
                  id="new-admin-email"
                  className="form-input"
                  type="email"
                  value={form.email}
                  onChange={(e) => setForm({ ...form, email: e.target.value })}
                  required
                  maxLength={120}
                />
              </div>
              <div className="form-group">
                <label className="form-label" htmlFor="new-admin-phone">Mobile number</label>
                <input
                  id="new-admin-phone"
                  className="form-input"
                  inputMode="tel"
                  placeholder="09XXXXXXXXX"
                  value={form.phone}
                  onChange={(e) => setForm({ ...form, phone: e.target.value })}
                  required
                />
              </div>
              <div className="form-group">
                <label className="form-label" htmlFor="new-admin-role">Role</label>
                <select
                  id="new-admin-role"
                  className="form-input"
                  value={form.role}
                  onChange={(e) => setForm({ ...form, role: e.target.value })}
                >
                  {roles.map((r) => (
                    <option key={r.value} value={r.value}>{r.label}</option>
                  ))}
                </select>
                <p className="adm-role-help">{ROLE_DESCRIPTIONS[form.role]}</p>
              </div>
              <p className="muted" style={{ fontSize: 13, margin: 0 }}>
                They&apos;ll get an email telling them to set their own password with <b>Forgot password</b> on the
                sign-in page. You never see or set it.
              </p>
              {formError ? <div className="error-banner">{formError}</div> : null}
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" type="button" onClick={() => setShowCreate(false)}>Cancel</button>
              <button className="btn btn-primary" type="submit" disabled={saving}>
                {saving ? "Adding…" : "Add admin"}
              </button>
            </div>
          </form>
        </div>
      ) : null}

      {roleEdit ? (
        <div className="modal-overlay open">
          <div className="modal" style={{ maxWidth: 440 }}>
            <div className="modal-header">
              <div className="modal-title">Change role — {roleEdit.admin.fullName}</div>
              <button className="modal-close" type="button" onClick={() => setRoleEdit(null)}>×</button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label className="form-label" htmlFor="change-admin-role">Role</label>
                <select
                  id="change-admin-role"
                  className="form-input"
                  value={roleEdit.role}
                  onChange={(e) => setRoleEdit({ ...roleEdit, role: e.target.value })}
                >
                  {roles.map((r) => (
                    <option key={r.value} value={r.value}>{r.label}</option>
                  ))}
                </select>
                <p className="adm-role-help">{ROLE_DESCRIPTIONS[roleEdit.role]}</p>
              </div>
              <p className="muted" style={{ fontSize: 13, margin: 0 }}>
                The change applies right away. {roleEdit.admin.fullName} is signed out and signs in again as{" "}
                {roleLabel(roleEdit.role)}.
              </p>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" type="button" onClick={() => setRoleEdit(null)}>Cancel</button>
              <button
                className="btn btn-primary"
                type="button"
                disabled={roleEdit.role === roleEdit.admin.role}
                onClick={saveRole}
              >
                Save role
              </button>
            </div>
          </div>
        </div>
      ) : null}

      <ConfirmDialog
        open={Boolean(confirm)}
        title={confirmCopy?.title}
        message={confirmCopy?.message}
        confirmLabel={confirmCopy?.label}
        danger={confirmCopy?.danger}
        onConfirm={confirmAction}
        onCancel={() => setConfirm(null)}
      />
    </div>
  );
}
