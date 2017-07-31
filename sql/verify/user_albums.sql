-- Verify fotostore:user_albums on sqlite

BEGIN;

select record_id, album_id, user_id from user_albums where 0;

ROLLBACK;
