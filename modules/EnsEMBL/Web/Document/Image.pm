# $Id: Image.pm,v 1.1 2012-12-10 16:25:19 ek3 Exp $
package EnsEMBL::Web::Document::Image;

use strict;
sub hover_labels {
  my $self    = shift;
  my $img_url = $self->hub->species_defs->img_url;
  my ($html, %done);
  
  foreach my $label (map values %{$_->{'hover_labels'} || {}}, @{$self->{'image_configs'}}) {
    next if $done{$label->{'class'}};
    
    my $desc   = join '', map "<p>$_</p>", split /; /, $label->{'desc'};
    my $subset = $label->{'subset'};
    my $renderers;
    
    foreach (@{$label->{'renderers'}}) {
      my $text = $_->{'text'};
      
      if ($_->{'current'}) {
        $renderers .= qq(<li class="current"><img src="${img_url}render/$_->{'val'}.gif" alt="$text" title="$text" /><img src="${img_url}tick.png" class="tick" alt="Selected" title="Selected" /> $text</li>);
      } else {
        $renderers .= qq(<li><a href="$_->{'url'}" class="config" rel="$label->{'component'}"><img src="${img_url}render/$_->{'val'}.gif" alt="$text" title="$text" /> $text</a></li>);
      }
    }
    
    $renderers .= qq{<li class="subset subset_$subset->[0]"><a class="modal_link force" href="$subset->[1]#$subset->[0]" rel="$subset->[2]"><img src="${img_url}16/setting.png" /> Configure track options</a></li>} if $subset;
    if ( exists $label->{'on-off'}) {
      $html .= sprintf(qq{
        <div class="hover_label floating_popup %s">
          <p class="header">%s</p>
          <a href="$label->{'off'}" class="config-update" rel="$label->{'component'}"><img src="${img_url}cross_red_13.png" alt="Turn track off" title="Turn track off" /></a>
          <div class="desc">%s</div>
          <div class="spinner"></div>
        </div>},
        $label->{'class'},
        $label->{'header'},
        $label->{'desc'}   ? qq{<img class="desc" src="${img_url}info_blue_13.png" alt="Info" title="Info" />} : '',
        $desc,
      );      
    } else {
      $html .= sprintf(qq(
        <div class="hover_label floating_popup %s">
          <p class="header">%s</p>
          %s
          %s
          %s
          <a href="$label->{'fav'}[1]" class="config favourite%s" rel="$label->{'component'}" title="Favourite track"></a>
          <a href="$label->{'off'}" class="config" rel="$label->{'component'}"><img src="${img_url}16/cross.png" alt="Turn track off" title="Turn track off" /></a>
          <div class="desc">%s</div>
          <div class="config">%s</div>
          <div class="url">%s</div>
          <div class="spinner"></div>
        </div>),
        $label->{'class'},
        $label->{'header'},
        $label->{'desc'}     ? qq(<img class="desc" src="${img_url}16/info.png" alt="Info" title="Info" />)                                  : '',
        $renderers           ? qq(<img class="config" src="${img_url}16/setting.png" alt="Change track style" title="Change track style" />) : '',
        $label->{'conf_url'} ? qq(<img class="url" src="${img_url}16/link.png" alt="Link" title="URL to turn this track on" />)              : '',

        $label->{'fav'}[0]   ? ' selected' : '',
        $desc,
        $renderers           ? qq(<p>Change track style:</p><ul>$renderers</ul>)                                                : '',
        $label->{'conf_url'} ? qq(<p>Copy <a href="$label->{'conf_url'}">this link</a> to force this track to be turned on</p>) : ''
      );
    }
  }
  
  return $html;
}

1;
