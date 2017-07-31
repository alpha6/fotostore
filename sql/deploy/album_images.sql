-- Deploy fotostore:album_images to sqlite
-- requires: images
-- requires: albums

BEGIN;

CREATE TABLE album_images (
    record_id INTEGER PRIMARY KEY AUTOINCREMENT,
    album_id  INTEGER REFERENCES albums (album_id),
    image_id  INTEGER REFERENCES images (file_id) 
);


COMMIT;
