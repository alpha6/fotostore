#!/usr/bin/perl
use strict;
use warnings;

use Mojolicious::Lite; # app, get, post is exported. 

use File::Basename 'basename';
use File::Path 'mkpath';
use Image::Magick;

# Image base URL
my $IMAGE_BASE = '/image-bbs/image';
my $ORIG_DIR = '/orig';
my $width = 640;
my $height = 480;

# Directory to save image files
# (app is Mojolicious object. static is MojoX::Dispatcher::Static object)
my $IMAGE_DIR  = app->static->root . $IMAGE_BASE;

# Create directory if not exists
unless (-d $IMAGE_DIR) {
    mkpath $IMAGE_DIR or die "Cannot create directory: $IMAGE_DIR";
    mkpath $IMAGE_DIR.$ORIG_DIR or die "Cannot create directory: $IMAGE_DIR$ORIG_DIR";
}

# Display top page
get '/' => sub {
    my $self = shift;
    
    # Get file names(Only base name)
    my @images = map {basename($_)} glob("$IMAGE_DIR/*.jpg $IMAGE_DIR/*.gif $IMAGE_DIR/*.png");
    
    # Sort by new order
    @images = sort {$b cmp $a} @images;
    
    # Render
    return $self->render(images => \@images, image_base => $IMAGE_BASE, orig => $ORIG_DIR);

} => 'index';

# Upload image file
post '/upload' => sub {
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
    my $filename = create_filename();
    my $image_file = "$IMAGE_DIR$ORIG_DIR/" . $filename. ".$ext";
    
    # If file is exists, Retry creating filename
    while(-f $image_file){
        $filename = create_filename();
        $image_file = "$IMAGE_DIR$ORIG_DIR/" . $filename . ".$ext";
    }
    
    # Save to file
    $image->move_to($image_file);
   
    $image = Image::Magick->new();
    $image->read($image_file);
    my ($ox, $oy) = $image->Get('base-columns', 'base-rows');
    if ($ox > $width ) {
        my $ny = (($oy/$ox)*$width);
        $image->Resize(geometry =>'geometry', width=>$width, height=>$ny);
    }
    $image->Write("$IMAGE_DIR/$filename.$ext");


    # Redirect to top page
    $self->redirect_to('index');
    
} => 'upload';

sub create_filename {
    
    # Date and time
    my ($sec, $min, $hour, $mday, $month, $year) = localtime;
    $month = $month + 1;
    $year = $year + 1900;
    
    # Random number(0 ~ 99999)
    my $rand_num = int(rand 100000);

    # Create file name form datatime and random number
    # (like image-20091014051023-78973)
    my $name = sprintf("image-%04s%02s%02s%02s%02s%02s-%05s",
                       $year, $month, $mday, $hour, $min, $sec, $rand_num);
    
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

@@ index.html.ep
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html;charset=UTF-8" >
    <title>Image BBS</title>
  </head>
  <body>
    <h1>Image BBS</h1>
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
        <div><a href='<%= "$image_base$orig/$image" %>'>Image original</a></div>
        <div>
          <img src="<%= "$image_base/$image" %>">
        </div>
      <div>
<% } %>
    </div>
  </body>
</html>
