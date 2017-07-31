-- Verify fotostore:album_images on sqlite

BEGIN;

select record_id, album_id, image_id from album_images where 0;

ROLLBACK;
