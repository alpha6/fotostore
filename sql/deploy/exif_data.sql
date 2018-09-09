-- Deploy fotostore:exif_data to sqlite

BEGIN;

CREATE TABLE `exif_data` (
	`record_id`	INTEGER PRIMARY KEY AUTOINCREMENT,
	`exif_tag`	TEXT NOT NULL,
	`tag_data`	TEXT NOT NULL,
	`image_id`	INTEGER NOT NULL,
	`deleted`	BOOLEAN DEFAULT 0
);

COMMIT;
