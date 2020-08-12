unit package Fez::CLI;

use Fez::Util::PW;
use Fez::Util::Json;
use Fez::Web;
use Fez::Bundle;

our $CONFIG = from-j(%?RESOURCES<config.json>.IO.slurp);

multi MAIN('register') is export {
  my ($em, $un, $pw);
  $em = prompt('#> Email: ') while ($em//'').chars < 6;
  $un = prompt('#> Username: ') while ($un//'').chars < 3;
  $pw = getpw('#> Password: ') while ($pw//'').chars < 8;

  my $response = post(
    '/register',
    data => { username => $un, email => $em, password => $pw },
  );

  if ! $response<success>.so {
    say "!> registration failed: {$response<message>}";
    exit 255;
  }
  say "#> registration successful, requesting auth key";
  my $*USERNAME = $un;
  my $*PASSWORD = $pw;
  MAIN('login');
}

multi MAIN('login') is export {
  my $un = $*USERNAME // '';
  my $pw = $*PASSWORD // '';
  $un = prompt('#> Username: ') while ($un//'').chars < 3;
  $pw = getpw('#> Password: ') while ($pw//'').chars < 8;

  my $response = post(
    '/login',
    data => { username => $un, password => $pw, }
  );
  if ! $response<success>.so {
    say "!> failed to login: {$response<message>}";
    exit 255;
  }

  $CONFIG<key> = $response<key>;
  $CONFIG<un>  = $un;
  %?RESOURCES<config.json>.IO.spurt(to-j($CONFIG));
  say "#> login successful, you can now upload dists";
}

multi MAIN('checkbuild', Bool :$auth-mismatch-error = False) is export {
  my $meta = try { from-j('./META6.json'.IO.slurp) } or do {
    say 'Unable to find META6.json';
    exit 255;
  };
  my $error = sub ($e) { say "!> $e"; exit 255; };

  $error('name should be a value') unless $meta<name>;
  $error('ver should not be nil')  unless $meta<ver>:exists;
  $error('auth should not be nil') unless $meta<auth>;
  $error('auth should start with "zef:"') unless $meta<auth>.substr(0,4) eq 'zef:';
  $error('ver cannot be "*"') if $meta<ver>.trim eq '*';

  #TODO: check for provides and resources matches in `lib` and `resources`

  if $meta<auth>.substr(4) ne ($CONFIG<un>//'<unset>') {
    printf "!> \"%s\" does not match the username you last logged in with (%s),\n!> you will need to login before uploading your dist\n\n",
           $meta<auth>.substr(4),
           ($CONFIG<un>//'unset');
    exit 255 if $auth-mismatch-error;
  }

  my $auth = $meta<name>
           ~ ':ver<'  ~ $meta<ver> ~ '>'
           ~ ':auth<' ~ $meta<auth>.subst(/\</, '\\<').subst(/\>/, '\\>') ~ '>';
  
  printf "%s looks OK\n", $auth;
}

multi MAIN('upload', Str :$file = '') is export {
  my $fn = $file;
  if '' ne $file && ! $file.IO.f {
    say "Cannot find $file";
    exit 255;
  }
  if '' eq $file {
    MAIN('checkbuild', :auth-mismatch-error);
    try {
      CATCH { default { printf "!> ERROR: %s\n", .message; exit 255; } }
      $fn = bundle('.'.IO.absolute);
    };
  }
  my $response = get(
    '/upload',
    headers => {'Authorization' => "Zef {$CONFIG<key>}"},
  );
 
  my $upload = post(
     $response<key>,
     :method<PUT>,
     :file($fn.IO.absolute),
  );

}
