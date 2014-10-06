# $Id: Export.pm,v 1.1 2012-12-10 16:25:19 ek3 Exp $

package EnsEMBL::Web::Object::Export;

sub process {  
  my $self           = shift;
  my $custom_outputs = shift || {};

  my $hub            = $self->hub;  
  my $o              = $hub->param('output');
  my $strand         = $hub->param('strand');

  my $object         = $self->get_object;   
  my @inputs         = ($hub->function eq 'Gene' || $hub->function eq 'LRG') ? $object->get_all_transcripts : @_;  
  @inputs            = [$object] if($hub->function eq 'Transcript');  

  my $slice          = $object->slice('expand');
  $slice             = $self->slice if($slice == 1);
   
  my $feature_strand = $slice->strand;
  $strand            = undef unless $strand == 1 || $strand == -1; # Feature strand will be correct automatically  
  $slice             = $slice->invert if $strand && $strand != $feature_strand;
  my $params         = { feature_strand => $feature_strand };
  my $html_format    = $self->html_format;

  if ($slice->length > 5000000) {
    my $error = 'The region selected is too large to export. Please select a region of less than 5Mb.';
    
    $self->string($error);    
  } else {
    my $outputs = {
      fasta     => sub { return $self->fasta(@inputs);  },
      csv       => sub { return $self->features('csv'); },
      tab       => sub { return $self->features('tab'); },
      bed       => sub { return $self->bed;    },
      gtf       => sub { return $self->features('gtf'); },
      psl       => sub { return $self->psl_features;    },
      gff       => sub { return $self->features('gff'); },
      gff3      => sub { return $self->gff3_features;   },
      embl      => sub { return $self->flat('embl');    },
      genbank   => sub { return $self->flat('genbank'); },
      alignment => sub { return $self->alignment;       },
      phyloxml  => sub { return $self->phyloxml('compara');},
      phylopan  => sub { return $self->phyloxml('compara_pan_ensembl');},
      %$custom_outputs
    };

    if ($outputs->{$o}) {      
      map { $params->{$_} = 1 if $_ } $hub->param('param');
      map { $params->{'misc_set'}->{$_} = 1 if $_ } $hub->param('misc_set'); 
      $self->params = $params;      
      $outputs->{$o}();
    }
  }
  
  my $string = $self->string;
  my $html   = $self->html; # contains html tags
  
  if ($html_format) {
    $string = "<pre>$string</pre>" if $string;
  } else {    
    if($o ne "phyloxml" && $o ne "phylopan"){
      s/<.*?>//g for $string, $html; # Strip html tags;
    }
    $string .= "\r\n" if $string && $html;
  }
  
  return ($string . $html) || 'No data available';
}

1;
