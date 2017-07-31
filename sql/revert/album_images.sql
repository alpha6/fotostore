-- Revert fotostore:album_images from sqlite

BEGIN;

DROP TABLE album_images;

COMMIT;
