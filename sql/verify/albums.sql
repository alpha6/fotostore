-- Verify fotostore:albums on sqlite

BEGIN;

select album_id, name, description, created, modified, deleted from albums where 0;

ROLLBACK;
