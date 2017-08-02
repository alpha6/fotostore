-- Verify fotostore:images on sqlite

BEGIN;

select file_id, owner_id, file_name, original_filename, created_time from images where 0;

ROLLBACK;
