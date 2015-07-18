sub Rect
{
  my ($top, $left, $bottom, $right) = @_;
  return { 'x' => $left, 'y' => $top,
           'w' => $right - $left, 'h' => $bottom - $top };
}

our $MODE = 'print';
  
our %rects = (
  'screen' => Rect(0, 0, 320, 640),
  'header' => Rect(0, 0, 18, 640),
  'footer' => Rect(302, 0, 320, 640),
  'full_text' => Rect(27, 72, 293, 568),
  'left' => Rect(27, 9, 293, 316),
  'right' => Rect(27, 324, 293, 631),
  'logon_graphic' => Rect(27, 9, 293, 631),
  );
our %colors = (
  'black' => [ 0, 0, 0 ],
  'border_background' => [ 10000/65535, 0, 0 ],
  'border_text' => [ 1, 0, 0 ],
  );
our @text_colors = (
  [0, 1, 0],
  [1, 1, 1],
  [1, 0, 0],
  [0, 40000/65535, 0],
  [0, 45232/65535, 51657/65535],
  [1, 59367/65535, 0],
  [45000/65535, 0, 0],
  [3084/65535, 0, 1],
  );
our %strings = (
  'marathon_name' => "U.E.S.C. Marathon",
  'starting_up' => "Opening Connection to " . chr(167) . ".4.5-23",
  'manufacturer' => "CAS.qterm//CyberAcme Systems Inc.",
  'address' => "<931.461.60231.14.vt920>",
  'terminal' => "UESCTerm 802.11 (remote override)",
  'scrolling' => "PgUp/PgDown/Arrows To Scroll",
  'ack' => "Return/Enter To Acknowledge",
  'disconnecting' => "Disconnecting...",
  'terminated' => "Connection Terminated.",
  'date_format' => "%H%M %m.%d.%Y",
  );
our @font_faces = (
  'fonts/Courier Prime.ttf',
  'fonts/Courier Prime Bold.ttf',
  'fonts/Courier Prime Italic.ttf',
  'fonts/Courier Prime Bold Italic.ttf',
  );
our %metrics = (
  'size' => 12,
  'size_pdf' => 11.7,
  'size_svg' => 11.7,
  );

1;
