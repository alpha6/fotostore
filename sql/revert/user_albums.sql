-- Revert fotostore:user_albums from sqlite

BEGIN;

DROP TABLE user_albums;

COMMIT;
