-- Revert fotostore:user_images from sqlite

BEGIN;

DROP TABLE user_images;

COMMIT;
