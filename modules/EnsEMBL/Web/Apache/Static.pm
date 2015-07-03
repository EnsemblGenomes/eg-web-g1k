package EnsEMBL::Web::Apache::Static;


sub mime_type {
  my $file    = shift;
  my $mimeobj = $MIME->mimeTypeOf($file);

  return 'application/octet-stream' if $file =~ /\.bam$/;

  return $mimeobj ? $mimeobj->type : 'text/plain';
}

1;
