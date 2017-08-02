#!/usr/bin/env perl
use strict;
use warnings;

use lib 'lib';
use Mojolicious::Lite;    # app, get, post is exported.

use File::Basename 'basename';
use File::Path 'mkpath';
use File::Spec 'catfile';
use Cwd;

use Imager;
use DBI;
use Digest::SHA;

use FotoStore::DB;

use Data::Dumper;
$Data::Dumper::Maxdepth = 3;

my $config = plugin 'Config' => { file => 'application.conf' };

my $db = FotoStore::DB->new( $config->{'db_file'} );

# Image base URL
my $IMAGE_BASE = 'images';
my $ORIG_DIR   = 'orig';

my $thumbs_size = 200;

my @scale_width = ( $thumbs_size, 640, 800, 1024 );

my $sha = Digest::SHA->new('sha256');

# Directory to save image files
# (app is Mojolicious object. static is MojoX::Dispatcher::Static object)
my $IMAGE_DIR = File::Spec->catfile( getcwd(), 'public', $IMAGE_BASE );

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
        # $self->app->log->debug("user id: [$user_id]");

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
    my $self = shift;
    my $username    = $self->req->param('username');
    my $password    = $self->req->param('password');
    my $fullname = $self->req->param('fullname');
    my $invite = $self->req->param('invite');

    if ($invite eq $config->{'invite_code'}) {
        #chek that username is not taken
        my $user = $db->get_user($username);
        if ($user->{'user_id'} > 0) {
            $self->render(template => 'error', message => 'Username already taken!');
            return 0;    
        }

        if ($fullname eq '') {
            $fullname = $username;
        }

        my $digest = $sha->add($password);
        $db->add_user($username, $digest->hexdigest(), $fullname);

        #Authenticate user after add
        if ( $self->authenticate( $username, $password ) ) {
            $self->redirect_to('/');
        }
        else {
            $self->render( text => 'Login failed :(' );
        }

    } else  {
        $self->render(template => 'error', message => 'invalid invite code');
    }
}; 

# Display top page
get '/' => sub {
    my $self = shift;

    my $current_user = $self->current_user;

} => 'index';

get '/get_images' => ( authenticated => 1 ) => sub {
    my $self = shift;

    my $current_user = $self->current_user;

    my $files_list = $db->get_files($current_user->{'user_id'}, 20);
    
    my $thumbs_dir = File::Spec->catfile( $IMAGE_DIR, $current_user->{'user_id'}, $thumbs_size );
    
    my @images = map { $_->{'file_name'} } @$files_list;

    my $images = [];

    for my $img_item (@$files_list) {
        my $file = $img_item->{'file_name'};
        my $img_hash = {};
        $img_hash->{'filename'} = $img_item->{'original_filename'};
        $img_hash->{'original_url'} =  File::Spec->catfile( '/', $IMAGE_BASE, $current_user->{'user_id'}, $ORIG_DIR, $file );
        $img_hash->{'thumbnail_url'} =  File::Spec->catfile( '/', $IMAGE_BASE, $current_user->{'user_id'}, $thumbs_size, $file );

        my @scaled = ();
        for my $scale (@scale_width) {
            push(@scaled, {'size' => $scale, 'url' => File::Spec->catfile( '/', $IMAGE_BASE, $current_user->{'user_id'}, $scale, $file )}) ;
        }

        $img_hash->{'scales'} = \@scaled;

        push(@$images, $img_hash);
    }    


    # Render
    return $self->render( json => $images );
};

# Upload image file
# There is no restriction for file size in app because restriction is present in nginx configuration
post '/upload' => ( authenticated => 1 ) => sub {
    my $self = shift;

    # Uploaded image(Mojo::Upload object)
    my $image = $self->req->upload('image');

    my $user = $self->current_user();
    my $user_id = $user->{'user_id'};
    $self->app->log->debug( "user:" . Dumper($user) );

    # Not upload
    unless ($image) {
        return $self->render(
            template => 'error',
            message  => "Upload fail. File is not specified."
        );
    }

    # Check file type
    my $image_type = $image->headers->content_type;
    my %valid_types = map { $_ => 1 } qw(image/gif image/jpeg image/png);

    # Content type is wrong
    unless ( $valid_types{$image_type} ) {
        return $self->render(
            template => 'error',
            message  => "Upload fail. Content type is wrong."
        );
    }

    # Extention
    my $exts = {
        'image/gif'  => 'gif',
        'image/jpeg' => 'jpg',
        'image/png'  => 'png'
    };
    my $ext = $exts->{$image_type};

    # Image file
    my $filename = sprintf( '%s.%s', create_hash( $image->slurp() ), $ext );
    my $image_file = File::Spec->catfile( get_path($user_id, $ORIG_DIR), $filename );

    # Save to file
    $image->move_to($image_file);

    my $imager = Imager->new();
    $imager->read( file => $image_file ) or die $imager->errstr;

    #http://sylvana.net/jpegcrop/exif_orientation.html
    #http://myjaphoo.de/docs/exifidentifiers.html
    my $rotation_angle = $imager->tags( name => "exif_orientation" ) || 1;
    $self->app->log->info(
        "Rotation angle [" . $rotation_angle . "] [" . $image->filename . "]" );

    if ( $rotation_angle == 3 ) {
        $imager = $imager->rotate( degrees => 180 );
    }
    elsif ( $rotation_angle == 6 ) {
        $imager = $imager->rotate( degrees => 90 );
    }

    for my $scale (@scale_width) {
        my $scaled = $imager->scale( xpixels => $scale );

        $scaled->write(
            file => File::Spec->catfile( get_path($user_id, $scale), $filename ) )
          or die $scaled->errstr;
    }

    if ( !$db->add_file( $user->{'user_id'}, $filename,  $image->filename) ) {

        #TODO: Send error msg
    }

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

    # Redirect to top page
    # $self->redirect_to('index');

} => 'upload';

sub create_hash {
    my $data_to_hash = shift;

    $sha->add($data_to_hash);
    return $sha->hexdigest();
}

sub get_path {
    my ($user_id, $size) = @_;
    my $path = File::Spec->catfile( $IMAGE_DIR, $user_id, $size );
    unless (-d $path) {
        mkpath $path or die "Cannot create directory: $path";
    }
    return $path;
}

app->start;
