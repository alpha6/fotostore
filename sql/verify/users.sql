-- Verify fotostore:users on sqlite

BEGIN;

SELECT user_id, nickname, password, fullname, timestamp
      FROM users
 WHERE 0;

ROLLBACK;
