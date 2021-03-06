unit class Fez::Util::Wget;

method get($url, :%headers = ()) {
  my @args = ('wget', '-qO-');
  @args.push('--header', "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  my $proc = run(|@args, :out, :err);
  die 'wget error: ' ~ $proc.err.slurp.trim if $proc.exitcode != 0;
  $proc.out.slurp;
}

method post($url, :$method = 'POST', :$data = '', :$file = '', :%headers = ()) {
  my @args = ('wget', '--method', $method, '-O-');
  @args.push('--body-data', $data) if $data;
  @args.push('--body-file', $file) if $file;

  @args.push('--header', "$_: {%headers{$_}}") for %headers.keys;
  @args.push($url);

  my $proc = run(|@args, :out, :err);
  die 'wget error: ' ~ $proc.err.slurp.trim if $proc.exitcode != 0;
  $proc.out.slurp;
}

method able {
  (run 'wget', '--version', :out, :err).exitcode == 0;
}
