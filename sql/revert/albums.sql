-- Revert fotostore:albums from sqlite

BEGIN;

DROP TABLE albums;

COMMIT;
