-- Deploy fotostore:albums to sqlite

BEGIN;

CREATE TABLE "albums" (
 `album_id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `name` STRING NOT NULL,
 `description` TEXT,
 `created` DATETIME DEFAULT (CURRENT_TIMESTAMP),
 `modified` DATETIME DEFAULT (CURRENT_TIMESTAMP),
 `deleted` BOOLEAN,
 `owner_id` INTEGER NOT NULL
 )

COMMIT;
