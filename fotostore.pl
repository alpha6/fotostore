#!/usr/bin/env perl
use strict;
use warnings;

use lib 'lib';
use Mojolicious::Lite;    # app, get, post is exported.
use Mojo::Promise;
use Mojo::IOLoop;

use File::Basename qw/basename fileparse/;
use File::Path 'mkpath';
use File::Spec 'catfile';
use Cwd;
use POSIX;

use Imager;
use DBI;
use Digest::SHA;

use FotoStore::DB;

use Data::Dumper;
$Data::Dumper::Maxdepth = 2;

my $config = plugin 'Config' => { file => 'application.conf' };

my $db = FotoStore::DB->new( $config->{'db_file'} );

# Image base URL
my $IMAGE_BASE = 'images';
my $ORIG_DIR   = 'orig';

# set allowed thumbnails scale and image scales
my $thumbs_size = $config->{'thumbnails_size'};

my $scales_map = $config->{'image_scales'};
$scales_map->{$thumbs_size} = 1;

#Sort and filter values for array of available scales
my @scale_width =
  map { $scales_map->{$_} == 1 ? $_ : undef }
  sort { $a <=> $b } keys(%$scales_map);

my $sha = Digest::SHA->new('sha256');

# Directory to save image files
my $IMAGE_DIR = File::Spec->catfile( getcwd(), 'public', $IMAGE_BASE );

my $log = Mojo::Log->new();

plugin 'authentication', {
    autoload_user => 1,
    load_user     => sub {
        my $self = shift;
        my $uid  = shift;

        return $db->get_user($uid);
    },
    validate_user => sub {
        my $self      = shift;
        my $username  = shift || '';
        my $password  = shift || '';
        my $extradata = shift || {};

        my $digest = $sha->add($password);

        my $user_id = $db->check_user( $username, $digest->hexdigest() );

        return $user_id;
    },
};

post '/login' => sub {
    my $self = shift;
    my $u    = $self->req->param('username');
    my $p    = $self->req->param('password');

    if ( $self->authenticate( $u, $p ) ) {
        $self->redirect_to('/');
    }
    else {
        $self->render( text => 'Login failed :(' );
    }

};

get '/logout' => sub {
    my $self = shift;

    $self->logout();
    $self->render( message => 'bye' );
};

get '/register' => ( authenticated => 0 ) => sub {

};

post '/register' => ( authenticated => 0 ) => sub {
    my $self     = shift;
    my $username = $self->req->param('username') || "";
    my $password = $self->req->param('password') || "";
    my $fullname = $self->req->param('fullname') || "";
    my $invite   = $self->req->param('invite') || "";

    if ( $invite eq $config->{'invite_code'} ) {

        #chek that username is not taken
        my $user = $db->get_user($username);
        if ( $user->{'user_id'} > 0 ) {
            $self->render(
                template => 'error',
                message  => 'Username already taken!'
            );
            return 0;
        }

        if ( $fullname eq '' ) {
            $fullname = $username;
        }

        my $digest = $sha->add($password);
        $db->add_user( $username, $digest->hexdigest(), $fullname );

        #Authenticate user after add
        if ( $self->authenticate( $username, $password ) ) {
            $self->redirect_to('/');
        }
        else {
            $self->render( template => 'error', message => 'Login failed :(' );
        }

    }
    else {
        $self->render( template => 'error', message => 'invalid invite code' );
    }
};

# Display top page
get '/' => sub {
    my $self = shift;

    my $current_user = $self->current_user;

} => 'index';

get '/get_images' => ( authenticated => 1 ) => sub {
    my $self = shift;

    #Getting current user
    my $current_user = $self->current_user;
    my $user_id      = $current_user->{'user_id'};

    #Getting images list with paging
    my $page = $self->param('page') || 1;
    my $items = $self->param('per-page') || 20;

    if (($page !~ /^\d+$/) || ($page <= 1)) { $page = 1}
    if (($items !~ /^\d+$/) || ($items <= 0)) { $items = 20}
    
    # process images list
    my $req_result = $db->get_files( $current_user->{'user_id'}, $items , $page);
    my $files_list = $req_result->{'images_list'};
    my $pages_count = ceil($req_result->{'total_rows'}/$items);

    my $thumbs_dir =
      File::Spec->catfile( $IMAGE_DIR, $current_user->{'user_id'},
        $thumbs_size );

    my @images = map { $_->{'file_name'} } @$files_list;

    my $images = [];

    for my $img_item (@$files_list) {
        my $file     = $img_item->{'file_name'};
        my $img_hash = {};
        $img_hash->{'id'} = $img_item->{'file_id'};
        $img_hash->{'filename'} = $img_item->{'original_filename'};
        $img_hash->{'original_url'} =
          File::Spec->catfile( '/', $IMAGE_BASE, $current_user->{'user_id'},
            $ORIG_DIR, $file );
        $img_hash->{'thumbnail_url'} =
          File::Spec->catfile( '/', $IMAGE_BASE, $current_user->{'user_id'},
            $thumbs_size, $file );

        my @scaled = ();
        for my $scale (@scale_width) {
            if ( -r File::Spec->catfile( get_path( $user_id, $scale ), $file ) )
            {
                push(
                    @scaled,
                    {
                        'size' => $scale,
                        'url'  => File::Spec->catfile(
                            '/', $IMAGE_BASE, $user_id, $scale, $file
                        )
                    }
                );
            }

        }

        $img_hash->{'scales'} = \@scaled;

        push( @$images, $img_hash );

        
    }

    my $reply_data = { current_page => $page, items_per_page => $items, pages_count => $pages_count, images_list => $images };

    # Render
    return $self->render( json => $reply_data );
};

# Upload image file
# There is no restriction for file size in app because restriction is present in nginx configuration
post '/upload' => ( authenticated => 1 ) => sub {
    my $self = shift;

    # Uploaded image(Mojo::Upload object)
    my $image = $self->req->upload('image');

    my $user    = $self->current_user();
    my $user_id = $user->{'user_id'};

    # Not upload
    unless ($image) {
        return $self->render(
            template => 'error',
            message  => "Upload fail. File is not specified."
        );
    }

    # Check file type
    my $image_type = $image->headers->content_type;
    my %valid_types = (
        'image/gif'  => 'gif',
        'image/jpeg' => 'jpg',
        'image/png'  => 'png'
    );

    # Content type is wrong
    unless ( $valid_types{$image_type} ) {
        return $self->render(
            template => 'error',
            message  => "Upload fail. Content type is wrong."
        );
    }

    my $ext = $valid_types{$image_type};

    # Image file
    my $filename = sprintf( '%s.%s', create_hash( $image->slurp() ), $ext );
    my $image_file =
      File::Spec->catfile( get_path( $user_id, $ORIG_DIR ), $filename );

    # Save to file
    $image->move_to($image_file);

    
    my $promise = store_image($image_file, $image->filename, $user_id);
    
    #TODO: add errors handling
    Mojo::Promise->all($promise)->then(sub {
        $self->render(
                json => {
                    files => [
                        {
                            name         => $image->filename,
                            size         => $image->size,
                            url          => sprintf( '/images/orig/%s', $filename ),
                            thumbnailUrl => sprintf( '/images/200/%s', $filename ),
                        }
                    ]
                }
            );
    })->wait;

} => 'upload';

sub create_hash {
    my $data_to_hash = shift;

    $sha->add($data_to_hash);
    return $sha->hexdigest();
}

sub get_path {
    my ( $user_id, $size ) = @_;
    my $path = File::Spec->catfile( $IMAGE_DIR, $user_id, $size );
    unless ( -d $path ) {
        mkpath $path or die "Cannot create directory: $path";
    }
    return $path;
}

sub store_image {
    my $image_file = shift;
    my $original_filename = shift;
    my $user_id = shift;

    my $promise = Mojo::Promise->new;
    # Process and store uploaded file in a separate process
    Mojo::IOLoop->subprocess(
        sub {
            my $subprocess = shift;

            my $filename = fileparse($image_file);
            my $imager = Imager->new();
            $imager->read( file => $image_file ) or die $imager->errstr;

            #http://sylvana.net/jpegcrop/exif_orientation.html
            #http://myjaphoo.de/docs/exifidentifiers.html
            my $rotation_angle = $imager->tags( name => "exif_orientation" ) || 1;
            $log->debug(
                "Rotation angle [" . $rotation_angle . "]" );

            if ( $rotation_angle == 3 ) {
                $imager = $imager->rotate( degrees => 180 );
            }
            elsif ( $rotation_angle == 6 ) {
                $imager = $imager->rotate( degrees => 90 );
            }

            my $original_width = $imager->getwidth();

            for my $scale (@scale_width) {

                #Skip sizes which more than original image
                if ( $scale >= $original_width ) {
                    next;
                }

                my $scaled = $imager->scale( xpixels => $scale );

                $scaled->write( file =>
                    File::Spec->catfile( get_path( $user_id, $scale ), $filename ) )
                or die $scaled->errstr;
            }

            if ( !$db->add_file( $user_id, $filename, $original_filename ) ) {

                $log->error(sprintf('Can\'t save file %s', $filename));
                die sprintf('Can\'t save file %s', $filename);
            }

            return $filename;
        },
        sub {
            my ($subprocess, $err, @results) = @_;
            $log->error("Subprocess error: $err") and return if $err;
            $promise->reject("Subprocess error: $err @results") if $err;
            $promise->resolve(1, @results);
        }
    );

    return $promise;
}

Mojo::IOLoop->start;
app->start;
