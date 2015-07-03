package EnsEMBL::Web::Component::UserData::PreviewConvertIDs;

use strict;

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = qq(<h2>Preview converted file(s)</h2>
<p>The first ten lines of each file are displayed below. Click on the file name to download the complete file</p>
);

  my @files = $object->param('converted') || $object->param('convert_file');
  my $i = 1;
  foreach my $id (@files) {
    next unless $id; 
    my ($file, $name, $gaps) = split(':', $id);

    ## Tidy up user-supplied names
    $name =~ s/ /_/g;
    if ($name !~ /\.txt$/i) {
      $name .= '.txt';
    }
    #$name = 'converted_'.$name;

    ## Fetch content
    my $prefix = $object->param('data_format') eq 'snp' ? 'user_upload' : 'export';
    my $tmpfile = EnsEMBL::Web::TmpFile::Text->new(
                    filename => $file, prefix => $prefix, extension => 'txt'
    );
    next unless $tmpfile->exists;
    my $data = $tmpfile->retrieve;
    if ($data) {
      my $newname = $name || 'converted_data_'.$i.'.txt';
      $html .= sprintf('<h3>File <a href="%s">%s</a></h3>', $tmpfile->URL, $newname);
      if ($gaps) {
        $html .= "<p>This data includes $gaps gaps where the input coordinates could not be mapped directly to the output assembly.</p>";
      }
      $html .= '<pre>';
      my $count = 1;
      foreach my $row ( split /\n/, $data ) {
        $html .= $row."\n";
        $count++;
        last if $count == 10;
      }
      $html .= '</pre>';
      $i++;
    }
  }
  
  return $html;
}

1;
