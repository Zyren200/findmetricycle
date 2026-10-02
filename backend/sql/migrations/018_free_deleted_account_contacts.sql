-- Deleted (archived) accounts kept their phone and email, which are UNIQUE,
-- so the same person could never sign up again — registration said
-- "already registered" while login said "not registered". Free them, the
-- same way deleting an account now does (user.model.js archiveUser).
UPDATE users
SET email = NULL, phone = CONCAT('deleted-', id)
WHERE deleted_at IS NOT NULL
  AND status = 'archived'
  AND phone NOT LIKE 'deleted-%';

-- A cleared email used to be saved as '' — a real value under the UNIQUE
-- index, so a second user clearing theirs hit a duplicate-key error.
UPDATE users SET email = NULL WHERE email = '';
