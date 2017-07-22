-- Revert fotostore:users from sqlite

BEGIN;

DROP TABLE users;

COMMIT;
