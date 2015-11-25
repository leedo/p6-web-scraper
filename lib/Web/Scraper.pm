use v6;

use URI;
use HTTP::UserAgent;
use Web::Scraper::Rule;
use XML::LibXML:from<Perl5>;
use XML::LibXML::XPathContext:from<Perl5>;

class Web::Scraper {
  has Web::Scraper::Rule %.rules;

  sub process ($selector, $name is copy, $type) is export {
    my $multiple = $name ~~ s/ '[]' $//;
    my $*rule = Web::Scraper::Rule.new(
      :selector($selector),
      :value($type),
      :multiple($multiple.Bool)
    );
    $*scraper.add-rule($name, $*rule);
  }

  sub scraper(&code) is export {
    my $*scraper = Web::Scraper.new;
    &code.();
    return $*scraper;
  }

  method add-rule (Str $name, Web::Scraper::Rule $rule) {
    %.rules{$name} = $rule;
  }

  multi method scrape (URI $uri) {
    my $ua = HTTP::UserAgent.new;
    my $res = $ua.get($uri.Str);

    if $res.is-success {
      return self.extract($res.content);
    }

    die $res.status-line;
  }

  multi method scrape (Str $content) {
    return self.extract($content);
  }

  multi method extract (Str $content) {
    my $xml = XML::LibXML.new(:recover(2));
    my $doc = $xml.load_html(:string($content));
    self.extract($doc);
  }

  multi method extract ($node) {
    return hash %.rules.kv.map: -> $name, $rule {
      $name => self.extract-rule($rule, $node);
    };
  }

  method extract-rule (Web::Scraper::Rule $rule, $node) {
    my @nodes = $node.findnodes($rule.selector);

    if !@nodes {
      die "{$rule.selector} matched no nodes inside: \n"
          ~ $node.toString.decode("utf-8").substr(0, 30);
    }

    if $rule.value ~~ Web::Scraper {
      return $rule.multiple
        ?? [@nodes.map: { $rule.value.extract($_) }]
        !! $rule.value.extract(@nodes[0]);
    }

    return $rule.multiple
      ?? [@nodes.map: { $rule.extract($_) }]
      !! $rule.extract(@nodes[0]);
  }
}
