package FotoStore::DB;

use v5.20;
use strict;
use warnings;

use feature qw(signatures say);
no warnings qw(experimental::signatures);

use Data::Dumper;
use DBIx::Struct;



sub new {
    my $class = shift;
    my $db_file = shift;

    my $dbix = DBIx::Struct::connect(sprintf('dbi:SQLite:dbname=%s', $db_file),"","");

    my $self = {
        dbix_connector => $dbix,
    };
    bless $self, $class;
    return $self;
}

sub check_user ($self, $nickname, $password) {
    my $row = one_row('users', { nickname => $nickname, password => $password });
    return $row->user_id;
}

sub get_user ($self, $user_id) {
    if ($user_id =~ /^\d+$/) {
        return $self->_get_user_by_user_id($user_id);
    } else {
        return $self->_get_user_by_username($user_id);
    }
}

sub _get_user_by_user_id ($self, $user_id) {
    my $row = one_row('users', {user_id => $user_id}) || return {};
    return {user_id => $row->user_id, nickname => $row->nickname, fullname => $row->fullname, timestamp => $row->timestamp};
}

sub _get_user_by_username($self, $username) {
    my $row = one_row('users', {nickname => $username}) || return {};
    return {user_id => $row->user_id, nickname => $row->nickname, fullname => $row->fullname, timestamp => $row->timestamp};
}


sub add_user($self, $username, $password, $fullname) {
    my $row = new_row('users', nickname => $username, password => $password, fullname => $fullname);
    return $row;
}


sub add_file($self, $user_id, $filename, $original_filename) {

    my $row = new_row('images',
        owner_id => $user_id,
        file_name => $filename, 
        original_filename => $original_filename
    );

    return $row;
}

sub get_files($self, $user_id, $items_count=20, $page=1) {

    # Calculate offset 
    # Pages in UI starts from 1, but here we need it to start from 0
    $page = 1 if ($page < 1);
    my $start_at = --$page * $items_count;

#    my ($rows_count) = $self->{'dbh'}->selectrow_array(q~select count(*) from images where owner_id=? ~, undef , $user_id);
    my $rows_count = one_row(['images' => -count => 'file_id', -where => { 'owner_id' => $user_id}] );

#    my $images_list = $self->{'dbh'}->selectall_arrayref(q~select * from images where owner_id=? order by created_time desc LIMIT ? OFFSET ? ~, { Slice => {} }, $user_id, $items_count, $start_at  );
    my $images_list = all_rows([
        'images'   =>
            -where => { 'owner_id' => $user_id },
        -limit     => $items_count,
        -offset    => $start_at
    ]);

    return { total_rows => $rows_count, images_list => $images_list };
}

sub add_album($self, $user_id, $album_name, $album_desc) {
    my $row = new_row('albums', name => $album_name, description => $album_desc, owner_id => $user_id);
    return $row;
}

sub save_tag($self, $db_file_id, $tag_name, $tag_value) {
    say STDERR ("[$db_file_id][$tag_name][$tag_value]");
    eval {
        my $row = new_row('exif_data', 'exif_tag' => $tag_name, 'tag_data' => $tag_value,'image_id' => $db_file_id, deleted => 0) || die "error!";
        say STDERR (Dumper($row));
        return $row;
    };
    if ($@) {
      say STDERR ("Error! $@");
    }
}


1;