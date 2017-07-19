#!/usr/bin/env perl
use strict;
use warnings;

use Mojolicious::Lite; # app, get, post is exported. 

use File::Basename 'basename';
use File::Path 'mkpath';
use File::Spec 'catfile';
use Cwd;

use Imager;

my $config = plugin 'Config'=> {file => 'application.conf'};;

my $predefined_user = 'alpha6';
my $predefined_password =  $config->{'password'};

die "No user password defined!" unless($predefined_password);

# Image base URL
my $IMAGE_BASE = 'images';
my $ORIG_DIR = 'orig';

my $thumbs_size = 200;

my @scale_width = ($thumbs_size, 640, 800, 1024);

# Directory to save image files
# (app is Mojolicious object. static is MojoX::Dispatcher::Static object)
my $IMAGE_DIR  = File::Spec->catfile(getcwd(), 'public', $IMAGE_BASE);

# Create directory if not exists
unless (-d $IMAGE_DIR) {
    mkpath $IMAGE_DIR or die "Cannot create directory: $IMAGE_DIR";
}

my $ORIG_PATH = File::Spec->catfile($IMAGE_DIR, $ORIG_DIR);
unless (-d $ORIG_PATH) {
    mkpath $ORIG_PATH or die "Cannot create directory: $ORIG_PATH";
}

for my $dir (@scale_width) {
    my $scaled_dir_path = File::Spec->catfile($IMAGE_DIR, $dir);
    unless (-d $scaled_dir_path) {
       mkpath $scaled_dir_path or die "Cannot create directory: $scaled_dir_path";
    }   
}

plugin 'authentication', {
    autoload_user => 1,
    load_user => sub {
        my $self = shift;
        my $uid  = shift;
 
        return {
            'username' => $predefined_user,
            'password' => $predefined_password,
            'name'     => 'User Name'
            } if ($uid eq 'userid' || $uid eq 'useridwithextradata');
        return undef;
    },
    validate_user => sub {
        my $self = shift;
        my $username = shift || '';
        my $password = shift || '';
        my $extradata = shift || {};
 
        # return 'useridwithextradata' if($username eq 'alpha6' && $password eq 'qwerty' && ( $extradata->{'ohnoes'} || '' ) eq 'itsameme');
        return 'userid' if($username eq $predefined_user && $password eq $predefined_password);
        return undef;
    },
};

post '/login' => sub {
    my $self = shift;
    my $u    = $self->req->param('username');
    my $p    = $self->req->param('password');
 
    if ($self->authenticate($u, $p)) {
        $self->redirect_to('/');
    } else {
        $self->render(text => 'Login failed :(');
    }
    
};

get '/logout' => sub {
    my $self = shift;
 
    $self->logout();
    $self->render(text => 'bye');
};

# Display top page
get '/' => sub {
    my $self = shift;
    
    my $thumbs_dir = File::Spec->catfile($IMAGE_DIR, $thumbs_size);
    # Get file names(Only base name)
    my @images = map {basename($_)} glob("$thumbs_dir/*.jpg $thumbs_dir/*.gif $thumbs_dir/*.png");
    
    # Sort by new order
    @images = sort {$b cmp $a} @images;
    
    # Render
    return $self->render(images => \@images, image_base => $IMAGE_BASE, orig => $ORIG_DIR, thumbs_size => $thumbs_size, scales => \@scale_width);

} => 'index';

# Upload image file
post '/upload' => (authenticated => 1)=> sub {
    my $self = shift;

    # Uploaded image(Mojo::Upload object)
    my $image = $self->req->upload('image');
    
    # Not upload
    unless ($image) {
        return $self->render(
            template => 'error', 
            message  => "Upload fail. File is not specified."
        );
    }
    
    # Upload max size
    #my $upload_max_size = 3 * 1024 * 1024;
    
    # Over max size
    #if ($image->size > $upload_max_size) {
    #    return $self->render(
    #        template => 'error',
    #        message  => "Upload fail. Image size is too large."
    #    );
    #}
    
    # Check file type
    my $image_type = $image->headers->content_type;
    my %valid_types = map {$_ => 1} qw(image/gif image/jpeg image/png);
    
    # Content type is wrong
    unless ($valid_types{$image_type}) {
        return $self->render(
            template => 'error',
            message  => "Upload fail. Content type is wrong."
        );
    }
    
    # Extention
    my $exts = {'image/gif' => 'gif', 'image/jpeg' => 'jpg',
                'image/png' => 'png'};
    my $ext = $exts->{$image_type};
    
    # Image file
    my $filename = create_filename($ext);
    my $image_file = File::Spec->catfile($ORIG_PATH,  $filename);
    
    # If file is exists, Retry creating filename
    while(-f $image_file){
        $filename = create_filename();
        $image_file = File::Spec->catfile($ORIG_PATH,  $filename);
    }
    
    # Save to file
    $image->move_to($image_file);
   
    my $imager = Imager->new();
    $imager->read(file => $image_file) or die $imager->errstr;

    for my $scale (@scale_width) {
        my $scaled = $imager->scale(xpixels => $scale);
        $scaled->write(file => File::Spec->catfile($IMAGE_DIR, $scale, $filename)) or die $scaled->errstr;
    }
   

    # Redirect to top page
    $self->redirect_to('index');
    
} => 'upload';

sub create_filename {
    my $ext = shift || 'jpg';
    
    # Date and time
    my ($sec, $min, $hour, $mday, $month, $year) = localtime;
    $month = $month + 1;
    $year = $year + 1900;
    
    # Random number(0 ~ 999999)
    my $rand_num = int(rand 1000000);

    # Create file name form datatime and random number
    # (like image-20091014051023-78973)
    my $name = sprintf('image-%04s%02s%02s%02s%02s%02s-%06s.%s',
                       $year, $month, $mday, $hour, $min, $sec, $rand_num, $ext);
    
    return $name;
}

app->start;

__DATA__

@@ error.html.ep
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html;charset=UTF-8" >
    <title>Error</title>
  </head>
  <body>
    <%= $message %>
  </body>
</html>

@@ no_logged.html.ep
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html;charset=UTF-8" >
    <title>Rough, Slow, Stupid, Contrary Photohosting</title>
  </head>
  <body>
    <h1>Rough, Slow, Stupid, Contrary Photohosting</h1>
    <form method="post" action="<%= url_for('login') %>" >
      <div>
        <input type="text" name="username" >
        <input type="password" name="password">
        <input type="submit" value="Login">
      </div>
    </form>
    </body>
</html>

@@ index.html.ep
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html;charset=UTF-8" >
    <title>Rough, Slow, Stupid, Contrary Photohosting</title>
  </head>
  <body>
    <h1>Rough, Slow, Stupid, Contrary Photohosting</h1>
    <% if (is_user_authenticated()) { %>
        <div><a href="/logout">Logout</a></div>
        <hr>
        <form method="post" action="<%= url_for('upload') %>" enctype ="multipart/form-data">
        <div>
            File name
            <input type="file" name="image" >
            <input type="submit" value="Upload" >
        </div>
        </form>
        <div>
<% foreach my $image (@$images) { %>
      <div>
        <hr>
        <div>
            <a href='<%= "/$image_base/$orig/$image" %>'>Image original</a>
            <% for my $scale (@$scales) { %>
                <a href='<%= "/$image_base/$scale/$image" %>'><%= $scale %></a>
            <% } %>
        </div>
        <div>
          <img src="<%= "/$image_base/$thumbs_size/$image" %>">
        </div>
      <div>
<% } %>
    </div>
    <% } else { %> 
        <form method="post" action="<%= url_for('login') %>" >
        <div>
            <input type="text" name="username" >
            <input type="password" name="password">
            <input type="submit" value="Login">
        </div>
        </form>
    <% } %>
    
  </body>
</html>
