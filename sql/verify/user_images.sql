-- Verify fotostore:user_images on sqlite

BEGIN;

select record_id, user_id, image_id from user_images where 0;

ROLLBACK;
