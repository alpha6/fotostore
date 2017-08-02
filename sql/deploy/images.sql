-- Deploy fotostore:images to sqlite

BEGIN;

ALTER TABLE images ADD COLUMN original_filename TEXT NOT NULL DEFAULT "Unknown";

COMMIT;
