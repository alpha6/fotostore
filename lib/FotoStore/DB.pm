package FotoStore::DB;

use strict;
use warnings;

use feature qw(signatures);
no warnings qw(experimental::signatures);

sub new {
    my $class = shift;
    my $db_file = shift;

    my $dbh = DBI->connect(sprintf('dbi:SQLite:dbname=%s', $db_file),"","");
    my $self = {
        dbh => $dbh,
    };
    bless $self, $class;
    return $self;
}

sub check_user ($self, $nickname, $password) {
    my ($user_id) = $self->{'dbh'}->selectrow_array(q~select user_id from users where nickname=? and password=?~, undef, ($nickname, $password));
    return $user_id;
}

sub get_user ($self, $user_id) {
    if ($user_id =~ /^\d+$/) {
        return $self->_get_user_by_user_id($user_id);
    } else {
        return $self->_get_user_by_username($user_id);
    }
}

sub _get_user_by_user_id ($self, $user_id) {
    my $user_data = $self->{'dbh'}->selectrow_hashref(q~select user_id, nickname, fullname, timestamp from users where user_id=?~, {}, ($user_id));
    return $user_data;
}

sub _get_user_by_username($self, $username) {
    my $user_data = $self->{'dbh'}->selectrow_hashref(q~select user_id, nickname, fullname, timestamp from users where nickname=?~, {}, ($username));
    return $user_data;
}


sub add_user($self, $username, $password, $fullname) {
    my $rows = $self->{'dbh'}->do(q~insert into users (nickname, password, fullname) values (?, ?, ?)~, undef, ($username, $password, $fullname));
    if ($self->{'dbh'}->errstr) {
        die $self->{'dbh'}->errstr;
    }
    return $rows;
}


sub add_file($self, $user_id, $filename, $original_filename) {
    my $rows =  $self->{'dbh'}->do(q~insert into images (owner_id, file_name, original_filename) values (?, ?, ?)~, undef, ($user_id, $filename, $original_filename));
    if ($self->{'dbh'}->errstr) {
        die $self->{'dbh'}->errstr;
    }
    return $rows;
}

sub get_files($self, $user_id, $count=20, $start_at=0) {
    return $self->{'dbh'}->selectall_arrayref(q~select * from images where owner_id=? order by created_time desc~, { Slice => {} }, $user_id );
}

1;