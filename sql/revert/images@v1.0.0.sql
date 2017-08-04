-- Revert fotostore:images from sqlite

BEGIN;

DROP TABLE images;

COMMIT;
